#!/bin/bash

echo "Starting 3-Tier App Setup - $(date)"

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

# Kill any old processes
pkill -f node || true
pkill httpd || true

# Start the app using nohup (simple and reliable)
nohup node app.js > /var/log/app.log 2>&1 &

echo "✅ Node.js app started with nohup - $(date)" >> /var/log/app.log

# Create health check file
echo "OK" > /var/www/myapp/health

echo "App setup completed at $(date)"
