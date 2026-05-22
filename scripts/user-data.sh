#!/bin/bash

# Update system
yum update -y

# Install Node.js and git
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs git

# Create app directory
mkdir -p /var/www/myapp
cd /var/www/myapp

# Clone or pull latest code
if [ -d ".git" ]; then
  git pull origin main
else
  git clone https://github.com/timkamba2002/aws-ha-autoscaling-project.git .
fi

cd app

# Install dependencies
npm ci --production

# Create .env file (temporary - we'll secure this later)
cat > .env << EOL
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
PORT=3000
EOL

# Start the app with PM2
npm install -g pm2
pm2 start app.js --name "3tier-app"
pm2 save
pm2 startup

echo "✅ 3-Tier App deployed successfully on $(hostname)"
