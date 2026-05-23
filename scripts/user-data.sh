#!/bin/bash

echo "=== Starting setup at $(date) ==="

# Update and install Node.js properly for Amazon Linux 2023
yum update -y
yum install -y nodejs git

# Verify Node.js
node --version || echo "Node.js installation failed"

mkdir -p /var/www/myapp
cd /var/www/myapp

# Clone or pull code
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

# Start the app
nohup node app.js > /var/log/app.log 2>&1 &

echo "OK" > /var/www/myapp/health

echo "=== Setup completed at $(date) ===" >> /var/log/app.log
