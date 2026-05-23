#!/bin/bash

yum update -y
yum install -y httpd

systemctl start httpd
systemctl enable httpd

cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>3-Tier AWS Architecture - Timothy Kamba</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        .header { text-align: center; color: #28a745; }
        .section { margin: 30px 0; padding: 20px; border: 1px solid #ddd; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>✅ 3-Tier Web Application</h1>
        <h2>Auto-Scaling, Load-Balanced Architecture</h2>
        <p><strong>Timothy Kamba - Cloud/DevOps Learning Project</strong></p>
    </div>

    <div class="section">
        <h3>Technologies Used</h3>
        <ul>
            <li><strong>Infrastructure:</strong> Terraform</li>
            <li><strong>Networking:</strong> VPC, Public/Private Subnets, NAT Gateway, Internet Gateway</li>
            <li><strong>Load Balancing:</strong> Application Load Balancer (ALB)</li>
            <li><strong>Compute:</strong> EC2 Auto Scaling Group + Launch Template</li>
            <li><strong>Database:</strong> RDS MySQL (Private Subnets)</li>
            <li><strong>CI/CD:</strong> GitHub Actions (Build → Test → Staging → Manual Approval → Production)</li>
            <li><strong>Security:</strong> Security Groups, IAM Roles, SSM Parameter Store</li>
        </ul>
    </div>

    <div class="section">
        <h3>Challenges Faced & Lessons Learned</h3>
        <ul>
            <li>Git large file issues with Terraform providers</li>
            <li>Health check configuration between ALB and EC2</li>
            <li>IAM Role + OIDC trust policy for GitHub Actions</li>
            <li>Debugging user-data.sh script execution on EC2</li>
            <li>Understanding rolling updates and instance refresh</li>
        </ul>
    </div>

    <div class="section">
        <h3>Status</h3>
        <p>✅ Infrastructure is live and auto-scaling</p>
        <p>✅ CI/CD pipeline is fully functional</p>
        <p>✅ Secrets managed via AWS SSM Parameter Store</p>
    </div>

    <p style="text-align:center; margin-top:50px;">
        <em>Built as a hands-on learning project to gain real Cloud/DevOps experience</em>
    </p>
</body>
</html>
HTML

echo "OK" > /var/www/html/health
echo "Portfolio page deployed - $(date)"
