#!/bin/bash
echo "=== React To-Do App Deployment Started - $(date) ==="

# Update and install Apache
yum update -y
yum install -y httpd

# Copy React build - try multiple possible locations
rm -rf /var/www/html/*

if [ -d "/tmp/build" ]; then
  echo "Copying from /tmp/build"
  cp -r /tmp/build/* /var/www/html/
elif [ -d "/tmp/app/build" ]; then
  echo "Copying from /tmp/app/build"
  cp -r /tmp/app/build/* /var/www/html/
else
  echo "ERROR: Build folder not found!" > /var/www/html/index.html
fi

# Start Apache
systemctl enable httpd
systemctl start httpd

echo "✅ React To-Do List Deployed Successfully at $(date)" > /var/www/html/health.html
echo "=== Deployment Complete ==="
