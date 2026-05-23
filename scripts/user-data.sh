#!/bin/bash

yum update -y
yum install -y httpd

systemctl start httpd
systemctl enable httpd

# Get secrets from SSM Parameter Store
DB_HOST=$(aws ssm get-parameter --name "/myapp/db/host" --with-decryption --query "Parameter.Value" --output text)
DB_USER=$(aws ssm get-parameter --name "/myapp/db/user" --with-decryption --query "Parameter.Value" --output text)
DB_NAME=$(aws ssm get-parameter --name "/myapp/db/name" --with-decryption --query "Parameter.Value" --output text)
DB_PASSWORD=$(aws ssm get-parameter --name "/myapp/db/password" --with-decryption --query "Parameter.Value" --output text)

cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html>
<head><title>3-Tier App</title></head>
<body>
    <h1>✅ 3-Tier Architecture Working</h1>
    <p>ALB + Auto Scaling Group + RDS</p>
    <p>Secrets loaded from AWS SSM Parameter Store</p>
    <p><strong>Timothy Kamba - Cloud/DevOps Project</strong></p>
</body>
</html>
HTML

echo "OK" > /var/www/html/health
echo "App deployed using SSM - $(date)"
