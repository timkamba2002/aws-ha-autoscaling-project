#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "=== HA Project Frontend Bootstrap Started - $(date) ==="

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
    .card { background:#1e293b; padding:2.5rem 3rem; border-radius:12px; text-align:center; max-width:420px; }
    .spinner { width:28px; height:28px; border:3px solid #334155; border-top-color:#60a5fa; border-radius:50%; animation:spin 0.9s linear infinite; margin:0 auto 1rem; }
    @keyframes spin { to { transform:rotate(360deg); } }
  </style>
</head>
<body>
  <div class="card">
    <div class="spinner"></div>
    <h1>🚀 Updating To-Do App</h1>
    <p>New version is rolling out. Please wait...</p>
  </div>
</body>
</html>
HTMLEOF

echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# INSTALL ONLY WHAT WE NEED FOR FRONTEND
# ============================================================
yum update -y || true
yum install -y nginx awscli unzip || true

# Stop any httpd that might be running and holding port 80
systemctl stop httpd 2>/dev/null || true
systemctl disable httpd 2>/dev/null || true

# ============================================================
# DEPLOY REACT FRONTEND FROM S3
# ============================================================
FRONTEND_BUCKET="${frontend_bucket}"
echo "Fetching React build from s3://$FRONTEND_BUCKET/frontend/current/"

mkdir -p /var/www/html
aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete 2>/dev/null || true

chown -R nginx:nginx /var/www/html 2>/dev/null || chown -R ec2-user:ec2-user /var/www/html 2>/dev/null || true
find /var/www/html -type d -exec chmod 755 {} + 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} + 2>/dev/null || true

echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# SIMPLE NGINX CONFIG - JUST SERVE THE REACT APP
# ============================================================
cat > /etc/nginx/conf.d/ha-frontend.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
NGINXEOF

rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true

systemctl enable nginx || true
systemctl restart nginx || true

echo "Nginx started for frontend"

# Final health check
echo "OK $(date -Iseconds)" > /var/www/html/health

echo "=== Frontend Bootstrap Complete - $(date) ==="
echo "Site should be live on port 80"