#!/bin/bash

echo "=== Starting Setup - $(date) ==="

yum update -y
yum install -y httpd

systemctl start httpd
systemctl enable httpd

# Fetch secrets from AWS SSM Parameter Store
DB_HOST=$(aws ssm get-parameter --name "/myapp/db/host" --with-decryption --query "Parameter.Value" --output text)
DB_USER=$(aws ssm get-parameter --name "/myapp/db/user" --with-decryption --query "Parameter.Value" --output text)
DB_NAME=$(aws ssm get-parameter --name "/myapp/db/name" --with-decryption --query "Parameter.Value" --output text)
DB_PASSWORD=$(aws ssm get-parameter --name "/myapp/db/password" --with-decryption --query "Parameter.Value" --output text)

cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>3-Tier AWS Project - Timothy Kamba</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 40px; }
        .success { color: #28a745; }
    </style>
</head>
<body>
    <h1 class="success">✅ 3-Tier Architecture Deployed Successfully!</h1>
    <p><strong>Auto Scaling + ALB + RDS</strong></p>
    <p>CI/CD Pipeline with GitHub Actions</p>
    <p>Secrets managed securely with <strong>AWS SSM Parameter Store</strong></p>
    <hr>
    <p><em>Timothy Kamba - Cloud/DevOps Learning Project</em></p>
</body>
</html>
HTML

echo "OK" > /var/www/html/health
echo "Deployment completed using SSM - $(date)"
