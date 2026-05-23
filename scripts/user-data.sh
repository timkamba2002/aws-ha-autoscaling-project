#!/bin/bash

echo "=== Simple Setup - $(date) ==="

yum update -y
yum install -y nodejs git

mkdir -p /var/www/myapp
cd /var/www/myapp

git clone https://github.com/timkamba2002/aws-ha-autoscaling-project.git . --depth 1 || git pull origin main

cd app

npm ci --production

cat > .env << EOL
DB_HOST=myapp-rds.cefo7yhuwfxg.us-east-1.rds.amazonaws.com
DB_USER=admin
DB_NAME=myappdb
DB_PASSWORD=Kd929986RDS!
PORT=3000
EOL

pkill -f node || true
pkill httpd || true

nohup node app.js > /var/log/app.log 2>&1 &

echo "OK" > /var/www/myapp/health

echo "Setup done at $(date)" >> /var/log/app.log
