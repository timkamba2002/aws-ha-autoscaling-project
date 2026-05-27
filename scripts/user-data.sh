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
FRONTEND_BUCKET="${FRONTEND_BUCKET:-ha-project-frontend-builds}"
echo "Fetching latest React build from s3://$FRONTEND_BUCKET/frontend/current/"

if aws s3 sync "s3://$FRONTEND_BUCKET/frontend/current/" /var/www/html/ --delete 2>/dev/null; then
  echo "✅ Synced React build from S3 current/"
else
  echo "⚠️  Trying latest.zip fallback..."
  if aws s3 cp "s3://$FRONTEND_BUCKET/frontend/latest.zip" /tmp/react-build.zip 2>/dev/null; then
    unzip -o /tmp/react-build.zip -d /var/www/html/
    rm -f /tmp/react-build.zip
  else
    cat > /var/www/html/index.html << 'EOF'
<!doctype html><html><body><h1>React app deploying...</h1><p>Upload pending from GitHub Actions.</p></body></html>
EOF
  fi
fi

# Permissions
chown -R apache:apache /var/www/html 2>/dev/null || true
find /var/www/html -type d -exec chmod 755 {} + 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} + 2>/dev/null || true

echo "OK $(date -Iseconds)" > /var/www/html/health

systemctl enable httpd
systemctl start httpd || systemctl restart httpd

echo "🚀 React frontend deployed on $(hostname) - $(date)"
