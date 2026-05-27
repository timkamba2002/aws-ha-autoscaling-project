#!/bin/bash
echo "=== Simple React Deployment - $(date) ==="

yum update -y
yum install -y httpd

rm -f /etc/httpd/conf.d/welcome.conf
rm -rf /var/www/html/*

cp -r /tmp/build/* /var/www/html/ 2>/dev/null || echo "<h1>React App Loading...</h1>" > /var/www/html/index.html

systemctl enable httpd
systemctl restart httpd

echo "✅ React To-Do App Deployed - $(date)" > /var/www/html/health.html
