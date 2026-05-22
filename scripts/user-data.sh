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

# Use environment variables passed from deployment
cat > .env << EOL
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_NAME=${DB_NAME}
DB_PASSWORD=${DB_PASSWORD}
PORT=3000
EOL

pkill -f node || true
pkill httpd || true

npm install -g pm2
pm2 start app.js --name "3tier-app"

echo "✅ App started with environment variables - $(date)" > /var/log/app.log
