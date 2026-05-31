#!/bin/bash
set +e

# ULTRA DEFENSIVE - Goal: Never 502 the ALB. Serve something fast.
mkdir -p /var/www/html

# Immediate placeholder so the site is never completely dead
cat > /var/www/html/index.html << 'HTMLEOF'
<!doctype html><html><body style="font-family:sans-serif;padding:2rem">
<h1>Instance is initializing...</h1>
<p>Please wait 1-2 minutes and refresh.</p>
</body></html>
HTMLEOF

echo "OK $(date -Iseconds)" > /var/www/html/health

# Minimal nginx config + start it immediately
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

systemctl enable nginx 2>/dev/null || true
systemctl start nginx || systemctl restart nginx || true

BOOTSTRAP_LOG="/var/www/html/bootstrap.log"
echo "=== Bootstrap started at $(date) ===" > "$BOOTSTRAP_LOG" 2>/dev/null || true

# Detect OS
if [ -f /etc/amazon-linux-release ]; then
  OS="al2"
else
  OS="al2023"
fi
echo "OS: $OS" >> "$BOOTSTRAP_LOG" 2>/dev/null || true

# Install packages (best effort)
if [ "$OS" = "al2" ]; then
  yum install -y awscli unzip nodejs npm nginx 2>/dev/null || true
else
  dnf install -y awscli unzip nodejs npm nginx 2>/dev/null || true
fi

# Frontend from S3 (best effort)
FRONTEND_BUCKET="${frontend_bucket}"
if aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete 2>/dev/null; then
  echo "Frontend synced from S3" >> "$BOOTSTRAP_LOG" 2>/dev/null || true
else
  echo "Frontend sync failed or not ready yet" >> "$BOOTSTRAP_LOG" 2>/dev/null || true
fi

chown -R nginx:nginx /var/www/html 2>/dev/null || true
find /var/www/html -type d -exec chmod 755 {} + 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} + 2>/dev/null || true

echo "OK $(date -Iseconds)" > /var/www/html/health

# Backend (best effort - will not break the frontend)
mkdir -p /opt/ha-backend
if aws s3 cp "s3://$FRONTEND_BUCKET/backend/backend.zip" /tmp/backend.zip 2>/dev/null; then
  unzip -o /tmp/backend.zip -d /opt/ha-backend/ 2>/dev/null || true
  rm -f /tmp/backend.zip
  cd /opt/ha-backend
  npm install --production 2>/dev/null || true

  cat > /etc/systemd/system/ha-backend.service << 'EOF'
[Unit]
Description=Backend
After=network.target
[Service]
WorkingDirectory=/opt/ha-backend
ExecStart=/usr/bin/node server.js
Restart=always
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable ha-backend
  systemctl start ha-backend || true
  echo "Backend service attempted" >> "$BOOTSTRAP_LOG" 2>/dev/null || true
else
  echo "No backend.zip found - API will not work" >> "$BOOTSTRAP_LOG" 2>/dev/null || true
fi

# Final guarantee
systemctl enable nginx
systemctl start nginx || systemctl restart nginx || true

echo "=== Bootstrap finished at $(date) ===" >> "$BOOTSTRAP_LOG" 2>/dev/null || true
echo "You can curl /bootstrap.log to see what happened" >> "$BOOTSTRAP_LOG" 2>/dev/null || true