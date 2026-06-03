resource "aws_security_group" "alb_sg" {
  count = var.create ? 1 : 0

  name        = "alb-sg"
  description = "Allow HTTP traffic from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

resource "aws_security_group" "ec2_sg" {
  count = var.create ? 1 : 0

  name        = "ec2-sg"
  description = "Allow traffic only from ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow ALB to reach EC2"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

# Data sources for non-dev envs
data "aws_security_group" "alb_sg" {
  count = var.create ? 0 : 1
  name  = "alb-sg"
}

data "aws_security_group" "ec2_sg" {
  count = var.create ? 0 : 1
  name  = "ec2-sg"
}
