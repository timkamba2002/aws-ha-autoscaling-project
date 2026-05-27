#!/bin/bash
echo "=== 3-Tier App Deployment - $(date) ==="

yum update -y
yum install -y httpd nodejs npm

# === Frontend (React) ===
rm -f /etc/httpd/conf.d/welcome.conf
rm -rf /var/www/html/*
if [ -d "/tmp/build" ]; then
  cp -r /tmp/build/* /var/www/html/
else
  echo "<h1>React App Loading...</h1>" > /var/www/html/index.html
fi

systemctl enable httpd
systemctl restart httpd

# === Backend (Node.js + RDS) ===
cd /home/ec2-user
if [ -d "backend" ]; then
  cd backend
  npm install --silent
  nohup node server.js > backend.log 2>&1 &
  echo "Backend started on port 3000"
fi

echo "✅ 3-Tier App is Live - $(date)" > /var/www/html/health.html
