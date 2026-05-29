#!/bin/bash
yum update -y
yum install -y httpd nodejs npm

rm -rf /var/www/html/*
cp -r /tmp/build/* /var/www/html/ 2>/dev/null || echo "<h1>App Loading...</h1>" > /var/www/html/index.html

systemctl start httpd

cd /home/ec2-user/backend
npm install
nohup node server.js > backend.log 2>&1 &
