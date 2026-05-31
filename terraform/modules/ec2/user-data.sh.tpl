#!/bin/bash
set +e

# ============================================================
# ULTRA EARLY: Make the web server healthy in the first 10 seconds
# This must succeed or the ALB will keep returning 502.
# ============================================================

mkdir -p /var/www/html
cat > /var/www/html/index.html << 'HTMLEOF'
<!doctype html><html><body style="font-family:sans-serif;padding:2rem">
<h1>Instance is initializing...</h1>
<p>Bootstrap is still running. Please wait 1-2 minutes and refresh.</p>
</body></html>
HTMLEOF

echo "OK $(date -Iseconds)" > /var/www/html/health

# Minimal nginx config that is almost impossible to break
cat > /etc/nginx/conf.d/ha-project.conf << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;

    location = /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINXEOF

# Start nginx immediately
systemctl enable nginx 2>/dev/null || true
systemctl start nginx || systemctl restart nginx || true

# Now set up logging
BOOTSTRAP_LOG="/var/www/html/bootstrap.log"
echo "=== HA Project Instance Bootstrap started at $(date) ===" > "$BOOTSTRAP_LOG" 2>/dev/null || true

# Detect OS
if [ -f /etc/amazon-linux-release ]; then
  OS="al2"
else
  OS="al2023"
fi
echo "OS: $OS" >> "$BOOTSTRAP_LOG" 2>/dev/null || true

# Detect Amazon Linux 2 vs 2023
if [ -f /etc/amazon-linux-release ]; then
  OS="al2"
else
  OS="al2023"
fi

echo "Detected OS family: $OS" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true

# ==================== INSTALL DEPENDENCIES ====================
echo "Installing dependencies..." | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
if [ "$OS" = "al2" ]; then
  yum update -y || true
  yum install -y awscli unzip nodejs npm nginx || true
else
  dnf update -y || true
  dnf install -y awscli unzip nodejs npm nginx || true
fi

# ==================== REACT FRONTEND (from S3) ====================
FRONTEND_BUCKET="${frontend_bucket}"
mkdir -p /var/www/html

echo "Fetching React build from s3://$FRONTEND_BUCKET/frontend/current/" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
if aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete 2>/dev/null; then
  echo "✅ React frontend synced" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
else
  echo "⚠️  Using fallback placeholder" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
  cat > /var/www/html/index.html << 'HTMLEOF'
<!doctype html><html><body style="font-family:sans-serif;padding:2rem">
<h1>🚀 React app deploying...</h1>
<p>Waiting for CI to upload build to S3.</p>
</body></html>
HTMLEOF
fi

chown -R nginx:nginx /var/www/html 2>/dev/null || chown -R ec2-user:ec2-user /var/www/html || true
find /var/www/html -type d -exec chmod 755 {} + 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} + 2>/dev/null || true

echo "OK $(date -Iseconds)" > /var/www/html/health

echo "Frontend setup complete" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true

# ==================== BACKEND (Node.js + Express) ====================
echo "Setting up backend..." | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
mkdir -p /opt/ha-backend
cd /opt/ha-backend

# Copy backend code from S3
BACKEND_BUCKET="$${BACKEND_BUCKET:-$$FRONTEND_BUCKET}"
if aws s3 cp "s3://$BACKEND_BUCKET/backend/backend.zip" /tmp/backend.zip 2>/dev/null; then
  unzip -o /tmp/backend.zip -d /opt/ha-backend/ || true
  rm -f /tmp/backend.zip
  echo "✅ Backend code deployed from S3" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
else
  echo "ℹ️  No backend.zip found - creating minimal server" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
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
echo "Backend npm install done" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true

# ==================== NGINX (simple and robust) ====================
echo "Configuring nginx..." | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true

# Very simple, hard-to-break nginx config
cat > /etc/nginx/conf.d/ha-project.conf << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/html;
    index index.html;

    # Always return 200 for ALB health check
    location = /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # API - proxy if backend is up, otherwise friendly error
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_intercept_errors on;
        error_page 502 503 504 = @api_down;
    }

    location @api_down {
        default_type application/json;
        return 503 '{"error":"backend_unavailable"}';
    }

    # Everything else = React SPA
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINXEOF

# Make sure nginx is always running
systemctl enable nginx || true
systemctl start nginx || systemctl restart nginx || true

echo "Nginx config applied" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true

# ==================== RUN BACKEND AS SYSTEMD SERVICE ====================
echo "Creating backend systemd service..." | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
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

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable ha-backend
if systemctl restart ha-backend; then
  echo "✅ Backend service started" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
else
  echo "⚠️ Backend service failed to start, trying start" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
  systemctl start ha-backend || true
fi

# ==================== CLOUDWATCH AGENT (basic, optional) ====================
if [ "$OS" = "al2" ]; then
  yum install -y amazon-cloudwatch-agent 2>/dev/null || true
else
  dnf install -y amazon-cloudwatch-agent 2>/dev/null || true
fi

# Final safety net: make sure nginx is running and health file exists
systemctl enable nginx || true
systemctl start nginx || true
echo "OK $(date -Iseconds)" > /var/www/html/health || true

echo "=== Bootstrap complete at $(date) ===" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
echo "Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || hostname)/" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true
echo "API health: curl http://localhost/api/health (via nginx)" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true

# Write final status for visibility (you can curl this from the browser)
echo "Bootstrap finished at $(date)" >> "$BOOTSTRAP_LOG" 2>/dev/null || true

systemctl status nginx --no-pager 2>/dev/null | head -5 || true
systemctl status ha-backend --no-pager 2>/dev/null | head -5 || true

echo "=== End of bootstrap ===" | tee -a "$BOOTSTRAP_LOG" 2>/dev/null || true

