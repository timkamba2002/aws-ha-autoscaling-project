#!/bin/bash

yum update -y
yum install -y httpd

systemctl start httpd
systemctl enable httpd

echo "<h1>✅ 3-Tier Infrastructure Working!</h1>
<p>ALB + ASG + RDS is deployed successfully.</p>
<p><a href='/db-test'>Check Database Later</a></p>" > /var/www/html/index.html

echo "OK" > /var/www/html/health

echo "Static page deployed at $(date)"
