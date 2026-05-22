resource "aws_launch_template" "lt" {
  name_prefix   = "ha-project-lt"
  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  network_interfaces {
    security_groups = [var.ec2_sg_id]
  }

  user_data = base64encode(<<EOF
#!/bin/bash
echo "Hello from Auto Scaling!" > /var/www/html/index.html
yum install -y httpd
systemctl start httpd
systemctl enable httpd
EOF
  )
}
