#!/bin/bash
echo "=== Starting React To-Do App Deployment - $(date) ==="

# Update system and install Apache
yum update -y
yum install -y httpd

# Copy the React build files from the artifact
rm -rf /var/www/html/*
cp -r /tmp/build/* /var/www/html/

# Start Apache
systemctl start httpd
systemctl enable httpd

echo "✅ React To-Do List App Deployed Successfully" > /var/www/html/health.html
echo "Deployment completed at $(date)" >> /var/www/html/health.html

echo "=== React App Deployment Complete ==="
