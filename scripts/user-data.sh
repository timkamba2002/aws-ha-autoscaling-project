#!/bin/bash
echo "=== React Deployment Debug - $(date) ==="

yum update -y
yum install -y httpd

rm -rf /var/www/html/*

# Simple test page
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head><title>React To-Do App</title></head>
<body style="font-family: Arial; text-align: center; padding: 50px;">
  <h1>✅ React To-Do List App</h1>
  <p>This is a test page from user-data.sh</p>
  <p>If you see this, the deployment script is working.</p>
</body>
</html>
HTML

echo "Test page deployed" > /var/www/html/health.html

systemctl enable httpd
systemctl restart httpd

echo "Deployment finished at $(date)"
