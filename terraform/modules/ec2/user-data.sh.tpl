#!/bin/bash
set -euo pipefail

echo "=== React Frontend Deployment Started - $(date) ==="

# Update and install Apache + AWS CLI (Amazon Linux 2)
yum update -y
yum install -y httpd awscli unzip

# Clean web root
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
    echo "❌ No build artifact found in S3 yet"
    cat > /var/www/html/index.html << 'HTMLEOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Deploying React App</title></head>
<body style="font-family: system-ui; padding: 2rem;">
  <h1>🚀 React app is deploying...</h1>
  <p>The frontend build has not been uploaded to S3 yet.</p>
  <p>Check GitHub Actions "deploy-frontend" job and verify the S3 bucket contents.</p>
</body></html>
HTMLEOF
  fi
fi

# Permissions for Apache on AL2
chown -R apache:apache /var/www/html 2>/dev/null || chown -R ec2-user:ec2-user /var/www/html 2>/dev/null || true
find /var/www/html -type d -exec chmod 755 {} + 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} + 2>/dev/null || true

# ALB target group health check (must return 200 on / or /health)
echo "OK $(date -Iseconds)" > /var/www/html/health

# Start web server
systemctl enable httpd
systemctl start httpd || systemctl restart httpd

echo "🚀 React frontend live at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || hostname) - $(date)"
echo "=== Deployment Complete ==="
