#!/bin/bash

# Update system
yum update -y

# Install Node.js and git
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs git

# Create app directory
mkdir -p /var/www/myapp
cd /var/www/myapp

# Clone or pull code
if [ -d ".git" ]; then
  git pull origin main
else
  git clone https://github.com/timkamba2002/aws-ha-autoscaling-project.git .
fi

cd app

# Install dependencies
npm ci --production

# Create .env file
cat > .env << EOL
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_NAME=${DB_NAME}
DB_PASSWORD=${DB_PASSWORD}
PORT=3000
EOL

# Kill any existing server (including Apache)
pkill -f node || true
pkill httpd || true
systemctl stop httpd || true

# Start the Node.js app with PM2
npm install -g pm2
pm2 start app.js --name "3tier-app"
pm2 save
pm2 startup

echo "✅ 3-Tier Node.js App started successfully on $(hostname) - $(date)"
