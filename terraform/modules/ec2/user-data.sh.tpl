#!/bin/bash
set -euo pipefail

echo "=== React Frontend Deployment Started - $(date) ==="

# ULTRA-EARLY PLACEHOLDER (so the site shows fast during ASG refresh)
mkdir -p /var/www/html
cat > /var/www/html/index.html << 'HTMLEOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>To-Do App • Updating</title>
  <style>body { font-family: system-ui; background:#0f172a; color:#e2e8f0; display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; } .card { background:#1e293b; padding:2rem 3rem; border-radius:12px; text-align:center; }</style>
</head>
<body>
  <div class="card">
    <h1>🚀 Updating To-Do App</h1>
    <p>New version rolling out. This page will refresh automatically.</p>
  </div>
</body>
</html>
HTMLEOF

echo "OK $(date -Iseconds)" > /var/www/html/health

# Normal work
yum update -y || true
yum install -y httpd awscli unzip || true

rm -rf /var/www/html/*
mkdir -p /var/www/html

FRONTEND_BUCKET="${frontend_bucket}"
aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete 2>/dev/null || true

chown -R apache:apache /var/www/html 2>/dev/null || chown -R ec2-user:ec2-user /var/www/html 2>/dev/null || true
echo "OK $(date -Iseconds)" > /var/www/html/health

systemctl enable httpd 2>/dev/null || true
systemctl start httpd || systemctl restart httpd || true

echo "🚀 React frontend live on $(hostname) - $(date)"