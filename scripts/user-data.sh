#!/bin/bash
echo "=== Full Stack Debug - $(date) ==="

yum update -y
yum install -y httpd nodejs npm mysql

# Frontend
rm -f /etc/httpd/conf.d/welcome.conf
rm -rf /var/www/html/*
systemctl enable httpd
systemctl start httpd

echo "<h1>Debug Page - $(date)</h1>" > /var/www/html/index.html
echo "OK - $(date)" > /var/www/html/health.html

# Backend
cd /home/ec2-user
if [ -d "backend" ]; then
  cd backend
  npm install --silent
  nohup node server.js > backend.log 2>&1 &
fi

# Debug RDS connection
echo "Trying to connect to RDS..." >> /var/www/html/debug.txt
mysql -h myapp-rds.cefo7yhuwfxg.us-east-1.rds.amazonaws.com -u admin -pKd929986DB! -e "USE myappdb; SHOW TABLES;" >> /var/www/html/debug.txt 2>&1 || echo "Connection failed" >> /var/www/html/debug.txt

echo "Debug finished" >> /var/www/html/debug.txt
