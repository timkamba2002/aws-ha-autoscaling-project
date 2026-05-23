#!/bin/bash

yum update -y
yum install -y httpd

systemctl start httpd
systemctl enable httpd

cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>3-Tier Web Application</title>
    <style>
        body { font-family: Arial; text-align: center; margin-top: 50px; }
        .success { color: green; }
    </style>
</head>
<body>
    <h1 class="success">✅ 3-Tier Architecture Deployed Successfully!</h1>
    <p><strong>Auto Scaling Group + ALB + RDS</strong></p>
    <p>This project was built using Terraform + GitHub Actions CI/CD</p>
    <hr>
    <p><em>Timothy Kamba - Cloud/DevOps Learning Project</em></p>
</body>
</html>
HTML

echo "OK" > /var/www/html/health

echo "Static production page deployed - $(date)"
