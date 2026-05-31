#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "=== HA Project Frontend Recovery Bootstrap - $(date) ==="

# ============================================================
# 1. IMMEDIATE PLACEHOLDER + HEALTH (ALB must see something fast)
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
    .card { background:#1e293b; padding:2rem 3rem; border-radius:12px; text-align:center; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🚀 Updating To-Do App</h1>
    <p>Please wait while the new version starts...</p>
  </div>
</body>
</html>
HTMLEOF

echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# 2. CLEAN UP ANY CONFLICTING SERVICES
# ============================================================
systemctl stop httpd 2>/dev/null || true
systemctl disable httpd 2>/dev/null || true
pkill -9 httpd 2>/dev/null || true

# ============================================================
# 3. INSTALL MINIMAL PACKAGES
# ============================================================
yum update -y || true
yum install -y nginx awscli unzip || true

# ============================================================
# 4. DEPLOY REACT FROM S3 (MOST IMPORTANT PART)
# ============================================================
FRONTEND_BUCKET="${frontend_bucket}"
echo "Downloading React build from s3://$FRONTEND_BUCKET/frontend/current/"

mkdir -p /var/www/html
if aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete 2>/dev/null; then
  echo "✅ Frontend synced successfully"
else
  echo "⚠️ S3 sync had issues - keeping placeholder"
fi

# Fix permissions
chown -R nginx:nginx /var/www/html 2>/dev/null || chown -R ec2-user:ec2-user /var/www/html 2>/dev/null || true
find /var/www/html -type d -exec chmod 755 {} + 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} + 2>/dev/null || true

echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# 5. SIMPLE NGINX CONFIG
# ============================================================
cat > /etc/nginx/conf.d/ha-app.conf << 'NGINXEOF'
server {
    listen 80 default_server;
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

# Test config and start/restart nginx
if nginx -t 2>/dev/null; then
  systemctl enable nginx || true
  systemctl restart nginx || true
  echo "✅ Nginx started successfully"
else
  echo "❌ Nginx config test failed"
  # Last resort - try to start anyway
  systemctl restart nginx 2>/dev/null || true
fi

echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# 6. FINAL VERIFICATION
# ============================================================
echo "=== Bootstrap finished at $(date) ==="
echo "Nginx status: $(systemctl is-active nginx 2>/dev/null || echo 'unknown')"
echo "Health file: $(cat /var/www/html/health 2>/dev/null || echo 'missing')"

# Write health one last time
echo "OK $(date -Iseconds)" > /var/www/html/health