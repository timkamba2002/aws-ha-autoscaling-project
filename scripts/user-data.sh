#!/bin/bash
echo "=== React To-Do App - $(date) ==="

yum update -y
yum install -y httpd

rm -f /etc/httpd/conf.d/welcome.conf
rm -rf /var/www/html/*
cp -r /tmp/build/* /var/www/html/ 2>/dev/null || echo "<h1>React To-Do App</h1>" > /var/www/html/index.html

systemctl enable httpd
systemctl restart httpd

echo "✅ React To-Do App is Live" > /var/www/html/health.html
