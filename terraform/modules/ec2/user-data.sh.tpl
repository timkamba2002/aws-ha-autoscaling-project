#!/bin/bash
set -euo pipefail

echo "=== React Frontend Deployment Started - $(date) ==="

# ============================================================
# ULTRA-EARLY PLACEHOLDER + HEALTH FILE
# This makes the site show something quickly during ASG refresh
# ============================================================
mkdir -p /var/www/html

cat > /var/www/html/index.html << 'HTMLEOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>To-Do App • Updating</title>
  <style>
    body { font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background:#0f172a; color:#e2e8f0; display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; }
    .card { background:#1e293b; padding:2.5rem 3rem; border-radius:12px; box-shadow:0 10px 30px rgba(0,0,0,0.4); max-width:420px; text-align:center; }
    h1 { margin:0 0 0.5rem; font-size:1.6rem; }
    .status { color:#94a3b8; font-size:0.95rem; margin-bottom:1rem; }
    .spinner { width:28px; height:28px; border:3px solid #334155; border-top-color:#60a5fa; border-radius:50%; animation:spin 0.9s linear infinite; margin:0 auto 1rem; }
    @keyframes spin { to { transform:rotate(360deg); } }
  </style>
</head>
<body>
  <div class="card">
    <div class="spinner"></div>
    <h1>🚀 Updating To-Do App</h1>
    <p class="status">New version is rolling out via ASG Instance Refresh.<br>This page will auto-refresh when ready.</p>
    <small style="color:#64748b">HA Project • Development</small>
  </div>
  <script>setTimeout(() => location.reload(), 25000);</script>
</body>
</html>
HTMLEOF

# Write health check immediately
echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# Real work
# ============================================================

yum update -y || true
yum install -y httpd awscli unzip || true

rm -rf /var/www/html/*
mkdir -p /var/www/html

FRONTEND_BUCKET="${frontend_bucket}"
echo "Fetching React build from s3://$FRONTEND_BUCKET/frontend/current/"

if aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete 2>/dev/null; then
  echo "✅ Synced React build from S3"
else
  echo "⚠️ Sync failed, keeping early placeholder"
fi

chown -R apache:apache /var/www/html 2>/dev/null || chown -R ec2-user:ec2-user /var/www/html 2>/dev/null || true
find /var/www/html -type d -exec chmod 755 {} + 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} + 2>/dev/null || true

echo "OK $(date -Iseconds)" > /var/www/html/health

systemctl enable httpd 2>/dev/null || true
systemctl start httpd || systemctl restart httpd || true

echo "🚀 React frontend live on $(hostname) - $(date)"
echo "=== Deployment Complete ==="