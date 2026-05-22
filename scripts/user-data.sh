#!/bin/bash

yum update -y
yum install -y nodejs git

mkdir -p /var/www/myapp
cd /var/www/myapp

if [ -d ".git" ]; then
  git pull origin main
else
  git clone https://github.com/timkamba2002/aws-ha-autoscaling-project.git .
fi

cd app

npm ci --production

cat > .env << EOL
DB_HOST=myapp-rds.cefo7yhuwfxg.us-east-1.rds.amazonaws.com
DB_USER=admin
DB_NAME=myappdb
DB_PASSWORD=Kd929986RDS!
PORT=3000
EOL

# Kill old processes
pkill -f node || true
pkill httpd || true
systemctl stop httpd || true

# Start the app
npm install -g pm2
pm2 start app.js --name "3tier-app"

echo "✅ 3-Tier App started on $(hostname) - $(date)" > /var/log/app.log
