#!/bin/bash
echo "=== React To-Do App Deployment - $(date) ==="

yum update -y
yum install -y httpd

# Copy React build from the artifact location
rm -rf /var/www/html/*
cp -r /tmp/build/* /var/www/html/ 2>/dev/null || echo "Build folder not found" > /var/www/html/index.html

systemctl enable httpd
systemctl start httpd

echo "✅ React To-Do List is Live!" > /var/www/html/health.html
echo "Deployment completed at $(date)" >> /var/www/html/health.html
