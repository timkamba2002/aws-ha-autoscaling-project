#!/bin/bash
echo "=== Full Stack Deployment - $(date) ==="

yum update -y
yum install -y httpd nodejs npm

# Frontend
rm -f /etc/httpd/conf.d/welcome.conf
rm -rf /var/www/html/*

cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html><head><title>Loading To-Do App...</title></head><body><h1>React To-Do App Loading...</h1></body></html>
HTML

systemctl enable httpd
systemctl start httpd

# Backend
cd /home/ec2-user
if [ -d "backend" ]; then
  cd backend
  npm install --silent
  nohup node server.js > backend.log 2>&1 &
  echo "Backend started"
fi

echo "✅ Full Stack Ready" > /var/www/html/health.html
