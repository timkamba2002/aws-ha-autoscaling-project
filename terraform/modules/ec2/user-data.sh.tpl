#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "=== HA Project Full Stack Bootstrap Started - $(date) ==="

# ============================================================
# ULTRA-EARLY PLACEHOLDER + HEALTH (protects frontend during rollout)
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
    .card { background:#1e293b; padding:2.5rem 3rem; border-radius:12px; text-align:center; max-width:420px; }
    .spinner { width:28px; height:28px; border:3px solid #334155; border-top-color:#60a5fa; border-radius:50%; animation:spin 0.9s linear infinite; margin:0 auto 1rem; }
    @keyframes spin { to { transform:rotate(360deg); } }
  </style>
</head>
<body>
  <div class="card">
    <div class="spinner"></div>
    <h1>🚀 Updating To-Do App</h1>
    <p>New version is rolling out. Frontend + Backend are being set up.</p>
  </div>
</body>
</html>
HTMLEOF

echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# INSTALL PACKAGES
# ============================================================
yum update -y || true
yum install -y httpd nginx nodejs npm unzip awscli || true

# ============================================================
# FRONTEND (React) - from S3 (this must keep working)
# ============================================================
FRONTEND_BUCKET="${frontend_bucket}"
echo "Fetching React frontend from s3://$FRONTEND_BUCKET/frontend/current/"
mkdir -p /var/www/html
aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete 2>/dev/null || true

chown -R apache:apache /var/www/html 2>/dev/null || chown -R ec2-user:ec2-user /var/www/html 2>/dev/null || true
echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# BACKEND SETUP (non-fatal if it fails - frontend still works)
# ============================================================
echo "=== Setting up Backend ==="
mkdir -p /opt/ha-backend
cd /opt/ha-backend

# Download backend zip (uploaded by GitHub Actions pipeline)
echo "Downloading backend from S3..."
aws s3 cp "s3://$FRONTEND_BUCKET/backend/backend.zip" /tmp/backend.zip 2>/dev/null || true

if [ -f /tmp/backend.zip ]; then
  unzip -o /tmp/backend.zip -d /opt/ha-backend/ || true
  rm -f /tmp/backend.zip
  echo "Backend code extracted"
else
  echo "WARNING: backend.zip not found in S3 - backend will not run"
fi

# Fetch secrets from SSM (best effort)
DB_PASSWORD=""
DB_HOST=""
DB_USER="admin"

echo "Attempting to fetch DB credentials from SSM..."
DB_PASSWORD=$(aws ssm get-parameter --name "/ha-project/development/db_password" --with-decryption --query "Parameter.Value" --output text 2>/dev/null || echo "")
DB_HOST=$(aws ssm get-parameter --name "/ha-project/development/db_host" --query "Parameter.Value" --output text 2>/dev/null || echo "")
DB_USER=$(aws ssm get-parameter --name "/ha-project/development/db_user" --query "Parameter.Value" --output text 2>/dev/null || echo "admin")

if [ -z "$DB_HOST" ]; then
  echo "DB_HOST not found in SSM - you may need to set /ha-project/development/db_host"
  # Fallback: try to use a common pattern (update this if needed after checking Terraform output)
  DB_HOST="myapp-rds.c3s0q0k0k0k0.us-east-1.rds.amazonaws.com"
fi

# Create .env for backend
if [ -d /opt/ha-backend ]; then
  cat > /opt/ha-backend/.env << EOF
PORT=3000
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=myappdb
NODE_ENV=production
EOF

  echo ".env created for backend"

  # Install backend dependencies
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

  systemctl daemon-reload || true
  systemctl enable ha-backend || true
  systemctl start ha-backend || true

  echo "Backend systemd service created and started (may take a moment)"
else
  echo "Skipping backend service - no code directory"
fi

# ============================================================
# NGINX CONFIG (serves frontend + proxies /api to backend)
# ============================================================
echo "Configuring nginx..."

cat > /etc/nginx/conf.d/ha-app.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.html;

    # Serve React frontend
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API calls to backend
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

# Remove default nginx config if it conflicts
rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true

systemctl enable nginx || true
systemctl start nginx || systemctl restart nginx || true

echo "Nginx configured and started"

# Final health file
echo "OK $(date -Iseconds)" > /var/www/html/health

# Clean up early placeholder if backend/frontend succeeded
if systemctl is-active --quiet nginx; then
  echo "Nginx is running - frontend should be live"
fi

echo "=== HA Project Bootstrap Complete - $(date) ==="
echo "Check logs: cat $LOG_FILE"
echo "Backend status: systemctl status ha-backend"
echo "Nginx status: systemctl status nginx"