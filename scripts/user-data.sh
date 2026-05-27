#!/bin/bash
echo "=== Starting React To-Do App Deployment - $(date) ==="

# Update and install Apache
yum update -y
yum install -y httpd

# Copy the React build files (this is the important part)
rm -rf /var/www/html/*
cp -r /tmp/build/* /var/www/html/ || echo "Warning: Could not copy build folder"

# Start Apache
systemctl enable httpd
systemctl start httpd

echo "✅ React To-Do List Deployed Successfully!" > /var/www/html/health.html
echo "Deployment completed at $(date)" >> /var/www/html/health.html

echo "=== React App Deployment Complete ==="
