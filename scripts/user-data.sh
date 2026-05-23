#!/bin/bash

yum update -y
yum install -y httpd

systemctl start httpd
systemctl enable httpd

cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head><title>3-Tier App</title></head>
<body>
    <h1>✅ 3-Tier Architecture is Working!</h1>
    <p>ALB + Auto Scaling Group + RDS</p>
    <p>CI/CD Pipeline is active</p>
    <p><strong>Timothy Kamba - Cloud/DevOps Project</strong></p>
</body>
</html>
HTML

echo "OK" > /var/www/html/health
echo "Static page deployed - $(date)"
