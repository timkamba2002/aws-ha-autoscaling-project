#!/bin/bash
echo "=== Full Stack Deployment - $(date) ==="

yum update -y
yum install -y httpd nodejs npm

# === Frontend (React) ===
rm -f /etc/httpd/conf.d/welcome.conf
rm -rf /var/www/html/*

# Simple loading page
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html><head><title>Loading...</title></head><body><h1>React To-Do App Loading...</h1></body></html>
HTML

systemctl enable httpd
systemctl start httpd

# === Backend (Node.js + RDS) ===
cd /home/ec2-user
if [ -d "backend" ]; then
  cd backend
  npm install --silent
  nohup node server.js > backend.log 2>&1 &
  echo "✅ Backend API started"
else
  echo "Backend folder not found" > /var/www/html/index.html
fi

echo "✅ Full Stack Ready - $(date)" > /var/www/html/health.html
echo "Deployment completed at $(date)"
