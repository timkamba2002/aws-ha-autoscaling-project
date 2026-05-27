#!/bin/bash
echo "=== Full Stack Deployment - $(date) ==="

yum update -y
yum install -y httpd nodejs npm

# Remove default welcome page
rm -f /etc/httpd/conf.d/welcome.conf

# Start Apache for React frontend
rm -rf /var/www/html/*
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>My To-Do List</title>
</head>
<body>
    <h1>React To-Do App Loading...</h1>
</body>
</html>
HTML

systemctl enable httpd
systemctl start httpd

# Start Backend API (Node.js)
cd /home/ec2-user
if [ ! -d "backend" ]; then
  echo "Backend folder not found"
else
  cd backend
  npm install
  nohup node server.js > backend.log 2>&1 &
  echo "Backend started on port 3000"
fi

echo "✅ Full Stack Deployed" > /var/www/html/health.html
