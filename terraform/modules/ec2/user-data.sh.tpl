#!/bin/bash
set -euo pipefail

echo "=== React Frontend Deployment Started - $(date) ==="

# ============================================================
# ULTRA-EARLY PLACEHOLDER + HEALTH (so ALB sees something fast
# during ASG Instance Refresh and user-data execution)
# This guarantees the site "shows" quickly even while yum and
# S3 sync are still running on fresh instances.
# ============================================================
mkdir -p /var/www/html
cat > /var/www/html/index.html << 'HTMLEOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>To-Do App • Deploying</title>
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

# Write health check file immediately so target group can pass as soon as httpd starts
echo "OK $(date -Iseconds)" > /var/www/html/health

# ============================================================
# NOW DO THE REAL WORK (installs + final S3 sync will overwrite the placeholder)
# ============================================================

# Update and install Apache + AWS CLI (Amazon Linux 2)
yum update -y || true
yum install -y httpd awscli unzip || true

# Clean web root (will be repopulated by S3 sync below)
rm -rf /var/www/html/*
mkdir -p /var/www/html

# === Download React build from S3 (populated by GitHub Actions) ===
FRONTEND_BUCKET="${frontend_bucket}"
echo "Fetching latest React build from s3://$FRONTEND_BUCKET/frontend/current/"

# Preferred: sync the current/ folder (CI uses aws s3 sync)
if aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete 2>/dev/null; then
  echo "✅ Synced React build from S3"
else
  echo "⚠️  Sync failed, trying latest.zip fallback..."
  if aws s3 cp "s3://$FRONTEND_BUCKET/frontend/latest.zip" /tmp/react-build.zip 2>/dev/null; then
    unzip -o /tmp/react-build.zip -d /var/www/html/
    rm -f /tmp/react-build.zip
    echo "✅ Extracted latest.zip"
  else
    echo "ℹ️ No build artifact found in S3 yet — keeping early placeholder"
    # Re-create a simple message if S3 is empty
    cat > /var/www/html/index.html << 'HTMLEOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Deploying React App</title></head>
<body style="font-family: system-ui; padding: 2rem; background:#0f172a; color:#e2e8f0;">
  <h1>🚀 React app is deploying...</h1>
  <p>The frontend build has not been uploaded to S3 yet.</p>
  <p>Check GitHub Actions "Deploy to Development" job.</p>
</body></html>
HTMLEOF
  fi
fi

# Permissions for Apache on AL2
chown -R apache:apache /var/www/html 2>/dev/null || chown -R ec2-user:ec2-user /var/www/html 2>/dev/null || true
find /var/www/html -type d -exec chmod 755 {} + 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} + 2>/dev/null || true

# Ensure health file exists (final version)
echo "OK $(date -Iseconds)" > /var/www/html/health

# Start web server
systemctl enable httpd 2>/dev/null || true
systemctl start httpd || systemctl restart httpd || true

echo "🚀 React frontend live on $(hostname) - $(date)"
echo "=== Deployment Complete ==="
