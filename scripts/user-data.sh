#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== HA Project Instance Bootstrap - $(date) ==="

# Detect Amazon Linux 2 vs 2023
if [ -f /etc/amazon-linux-release ]; then
  OS="al2"
else
  OS="al2023"
fi

echo "Detected OS family: $OS"

# ==================== INSTALL DEPENDENCIES ====================
if [ "$OS" = "al2" ]; then
  yum update -y
  yum install -y httpd awscli unzip nodejs npm nginx
else
  dnf update -y
  dnf install -y httpd awscli unzip nodejs npm nginx
fi

# ==================== REACT FRONTEND (from S3) ====================
FRONTEND_BUCKET="${FRONTEND_BUCKET:-ha-project-frontend-builds}"
mkdir -p /var/www/html

echo "Fetching React build from s3://$FRONTEND_BUCKET/frontend/current/"
if aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete 2>/dev/null; then
  echo "✅ React frontend synced"
else
  echo "⚠️  Using fallback placeholder"
  cat > /var/www/html/index.html << 'HTMLEOF'
<!doctype html><html><body style="font-family:sans-serif;padding:2rem">
<h1>🚀 React app deploying...</h1>
<p>Waiting for CI to upload build to S3.</p>
</body></html>
HTMLEOF
fi

chown -R apache:apache /var/www/html 2>/dev/null || chown -R ec2-user:ec2-user /var/www/html || true
find /var/www/html -type d -exec chmod 755 {} + 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} + 2>/dev/null || true

echo "OK $(date -Iseconds)" > /var/www/html/health

# ==================== BACKEND (Node.js + Express) ====================
mkdir -p /opt/ha-backend
cd /opt/ha-backend

# Copy backend code from S3 (you must upload backend/ folder as zip in CI)
BACKEND_BUCKET="${BACKEND_BUCKET:-$FRONTEND_BUCKET}"
if aws s3 cp "s3://$BACKEND_BUCKET/backend/backend.zip" /tmp/backend.zip 2>/dev/null; then
  unzip -o /tmp/backend.zip -d /opt/ha-backend/
  rm -f /tmp/backend.zip
  echo "✅ Backend code deployed from S3"
else
  echo "ℹ️  No backend.zip found - creating minimal server for demo"
  # Fallback minimal server so /api works even without full deploy
  cat > /opt/ha-backend/server.js << 'EOF'
const express = require('express');
const app = express();
app.use(express.json());
app.get('/health', (req,res) => res.json({status:'ok', mode:'fallback'}));
app.get('/api/tasks', (req,res) => res.json([]));
app.post('/api/tasks', (req,res) => res.status(201).json({id:'demo', ...req.body}));
app.put('/api/tasks/:id', (req,res) => res.json({id:req.params.id, ...req.body}));
app.listen(3000, () => console.log('Fallback backend on 3000'));
EOF
  cat > /opt/ha-backend/package.json << 'EOF'
{ "name":"fallback", "version":"1.0.0", "dependencies":{ "express":"^4.18.2" } }
EOF
fi

cd /opt/ha-backend
npm install --production 2>&1 | tail -5 || true

# ==================== NGINX REVERSE PROXY (React + API) ====================
cat > /etc/nginx/conf.d/ha-project.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.html;

    # Health check for ALB
    location = /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # API proxy to Node backend on port 3000
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # React SPA - all other routes return index.html
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINXEOF

# Enable and start Nginx
systemctl enable nginx
systemctl restart nginx || systemctl start nginx

# ==================== RUN BACKEND AS SYSTEMD SERVICE ====================
cat > /etc/systemd/system/ha-backend.service << 'SERVICEEOF'
[Unit]
Description=HA Project Backend API
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/ha-backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=DB_HOST=${DB_HOST}
Environment=DB_NAME=${DB_NAME}
Environment=DB_USER=${DB_USER}
Environment=DB_PASSWORD=${DB_PASSWORD}
Environment=DB_PORT=5432
Environment=CLOUDWATCH_LOG_GROUP=/aws/ec2/ha-project-backend
Environment=ENVIRONMENT=${ENVIRONMENT}
Environment=AWS_REGION=${AWS_REGION}

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable ha-backend
systemctl restart ha-backend || systemctl start ha-backend

# ==================== CLOUDWATCH AGENT (basic) ====================
if [ "$OS" = "al2" ]; then
  yum install -y amazon-cloudwatch-agent 2>/dev/null || true
else
  dnf install -y amazon-cloudwatch-agent 2>/dev/null || true
fi

echo "=== Bootstrap complete at $(date) ==="
echo "Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || hostname)/"
echo "API health: curl http://localhost/api/health (via nginx)"
systemctl status nginx --no-pager || true
systemctl status ha-backend --no-pager || true
