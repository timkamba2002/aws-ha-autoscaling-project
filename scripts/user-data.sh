#!/bin/bash
echo "=== React To-Do App Deployment Started - $(date) ==="

yum update -y
yum install -y httpd

# Clean previous files
rm -rf /var/www/html/*

# Copy React build - GitHub Actions downloads as folder contents
if [ -d "/tmp/build" ]; then
    echo "✅ Found /tmp/build - copying React app"
    cp -r /tmp/build/* /var/www/html/
elif ls /tmp/index.html >/dev/null 2>&1; then
    echo "✅ Found build files directly in /tmp"
    cp -r /tmp/* /var/www/html/ 2>/dev/null || true
else
    echo "❌ Build not found - using fallback" > /var/www/html/index.html
fi

# Start web server
systemctl enable httpd
systemctl start httpd

echo "🚀 React To-Do List Deployed Successfully - $(date)" > /var/www/html/health.html
echo "=== Deployment Complete ==="
