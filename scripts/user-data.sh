#!/bin/bash
echo "=== React To-Do App Deployment - $(date) ==="

yum update -y
yum install -y httpd

# Remove default Apache welcome page completely
rm -f /etc/httpd/conf.d/welcome.conf

# Clean and set permissions
rm -rf /var/www/html/*
chmod -R 755 /var/www/html

# Create our React placeholder
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Timothy Kamba - React To-Do App</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 60px; background: #f4f4f4; }
        h1 { color: #28a745; }
        p { font-size: 18px; }
    </style>
</head>
<body>
    <h1>✅ React To-Do List App</h1>
    <p><strong>Successfully Deployed via CI/CD Pipeline</strong></p>
    <p>Timothy Kamba - Cloud/DevOps Project</p>
    <hr>
    <p>This is a test page. Real React app coming soon.</p>
</body>
</html>
HTML

echo "OK - $(date)" > /var/www/html/health.html

systemctl enable httpd
systemctl restart httpd

echo "Deployment finished - $(date)"
