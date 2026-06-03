#!/bin/bash
# Redirect all output to a log file + console for easier debugging later
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

set -euo pipefail

echo "=== HA Project Full Stack Bootstrap - $(date) ==="

# ============================================================
# ULTRA-EARLY PLACEHOLDER + HEALTH (keeps ALB happy during refresh)
# ============================================================
mkdir -p /var/www/html

cat > /var/www/html/index.html << 'HTMLEOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>To-Do App • Updating</title>
  <style>
    body { font-family: system-ui; background:#0f172a; color:#e2e8f0; display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; }
    .card { background:#1e293b; padding:2.5rem 3rem; border-radius:12px; text-align:center; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🚀 Updating To-Do App</h1>
    <p>New version is rolling out. Please wait...</p>
  </div>
</body>
</html>
HTMLEOF

echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# SET REGION EARLY (critical for all aws cli calls)
# ============================================================
export AWS_DEFAULT_REGION=us-east-1
echo "AWS region set to $AWS_DEFAULT_REGION"

# ============================================================
# INSTALL REQUIRED PACKAGES (Amazon Linux 2 specific)
# ============================================================
echo "=== Installing base packages ==="

# Update and install common tools
yum update -y || true

# Install base packages (httpd is only for cleanup)
yum install -y httpd unzip awscli || true

# Stop/disable Apache (we use nginx instead)
systemctl stop httpd 2>/dev/null || true
systemctl disable httpd 2>/dev/null || true

# --- Node.js 16 via NodeSource (required on AL2 due to glibc) ---
echo "=== Installing Node.js 16 via NodeSource ==="
curl -fsSL https://rpm.nodesource.com/setup_16.x | bash - || true
yum install -y nodejs || true
node --version || echo "WARNING: node not found after install"

# --- Nginx via amazon-linux-extras (correct way on AL2) ---
echo "=== Installing nginx via amazon-linux-extras ==="
amazon-linux-extras install nginx1 -y || true
nginx -v || echo "WARNING: nginx not found after install"

# ============================================================
# DEPLOY REACT FRONTEND FROM S3
# ============================================================
FRONTEND_BUCKET="${frontend_bucket}"
echo "Fetching React build from s3://$FRONTEND_BUCKET/frontend/current/"

mkdir -p /var/www/html
if aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete; then
  echo "Frontend synced successfully"
else
  echo "WARNING: Frontend sync had issues"
fi

chown -R nginx:nginx /var/www/html 2>/dev/null || chown -R ec2-user:ec2-user /var/www/html 2>/dev/null || true
find /var/www/html -type d -exec chmod 755 {} + 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} + 2>/dev/null || true

echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# DEPLOY NODE BACKEND
# ============================================================
echo "=== Setting up Backend ==="

mkdir -p /opt/ha-backend
cd /opt/ha-backend

# Download backend code (uploaded by GitHub Actions)
if aws s3 cp "s3://$FRONTEND_BUCKET/backend/backend.zip" /tmp/backend.zip; then
  unzip -o /tmp/backend.zip -d /opt/ha-backend/
  rm -f /tmp/backend.zip
  echo "Backend code extracted"
else
  echo "WARNING: Could not download backend.zip"
fi

# Fetch DB credentials from SSM (region is already set above)
echo "Fetching DB credentials from SSM..."
DB_HOST=$(aws ssm get-parameter --name "/ha-project/development/db_host" --query "Parameter.Value" --output text 2>/dev/null || echo "")
DB_USER=$(aws ssm get-parameter --name "/ha-project/development/db_user" --query "Parameter.Value" --output text 2>/dev/null || echo "admin")
DB_PASSWORD=$(aws ssm get-parameter --name "/ha-project/development/db_password" --with-decryption --query "Parameter.Value" --output text 2>/dev/null || echo "")

if [ -z "$DB_HOST" ]; then
  echo "ERROR: Could not retrieve DB_HOST from SSM. Backend will fail to connect."
else
  echo "DB credentials retrieved successfully"
fi

# Create .env for backend
cat > /opt/ha-backend/.env << EOF
PORT=3000
DB_HOST=$DB_HOST
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_NAME=myappdb
NODE_ENV=production
EOF

echo ".env created"

# Install backend dependencies (in case zip is incomplete)
cd /opt/ha-backend
npm install --production 2>&1 | tail -5 || true

# Create systemd service for backend
cat > /etc/systemd/system/ha-backend.service << 'SERVICEEOF'
[Unit]
Description=HA Project Backend
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/ha-backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable ha-backend
systemctl start ha-backend || echo "WARNING: Backend service start had issues"

echo "Backend service attempted to start. Current status: $(systemctl is-active ha-backend || true)"

# ============================================================
# NGINX AS REVERSE PROXY (Frontend + API)
# ============================================================
echo "=== Configuring Nginx ==="

cat > /etc/nginx/conf.d/ha-app.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    # Serve React frontend
    location / {
        root /var/www/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # Proxy API calls to Node backend
    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Health check for ALB
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
NGINXEOF

rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true

if nginx -t; then
  systemctl enable nginx
  systemctl restart nginx
  echo "Nginx configured and started successfully"
else
  echo "ERROR: nginx configuration test failed"
fi

echo "Nginx status: $(systemctl is-active nginx || true)"

# Final health file
echo "OK $(date -Iseconds)" > /var/www/html/health

echo "=== Full Stack Bootstrap Complete - $(date) ==="
echo "Frontend: http://localhost/"
echo "API:      http://localhost/api/"
echo "Backend service status: $(systemctl is-active ha-backend || true)"
echo "Check /var/log/user-data.log for detailed bootstrap logs"