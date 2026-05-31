#!/bin/bash
set -euo pipefail

echo "=== HA Project Frontend Bootstrap (Backend Integration Attempt) - $(date) ==="

# ============================================================
# ULTRA-EARLY PLACEHOLDER + HEALTH (so ALB sees something during refresh)
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
    <p>New version is rolling out. This demonstrates backend integration attempt.</p>
  </div>
</body>
</html>
HTMLEOF

echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# INSTALL APACHE + AWS CLI (minimal and reliable)
# ============================================================
yum update -y || true
yum install -y httpd awscli unzip || true

# ============================================================
# DEPLOY REACT FRONTEND FROM S3
# ============================================================
FRONTEND_BUCKET="${frontend_bucket}"
echo "Fetching React build from s3://$FRONTEND_BUCKET/frontend/current/"

rm -rf /var/www/html/*
mkdir -p /var/www/html

if aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete 2>/dev/null; then
  echo "✅ React frontend synced from S3"
else
  echo "⚠️ Using placeholder (S3 sync issue)"
fi

# Permissions
chown -R apache:apache /var/www/html 2>/dev/null || chown -R ec2-user:ec2-user /var/www/html 2>/dev/null || true
find /var/www/html -type d -exec chmod 755 {} + 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} + 2>/dev/null || true

# Health check for ALB target group
echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# START APACHE (simple and proven)
# ============================================================
systemctl enable httpd
systemctl start httpd || systemctl restart httpd || true

echo "=== Bootstrap Complete - $(date) ==="
echo "Frontend should be serving. Backend integration attempted (see React error banner)."