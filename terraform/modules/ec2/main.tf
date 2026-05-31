resource "aws_iam_role" "ec2_role" {
  name = "ha-project-ec2-frontend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "ha-project-ec2-frontend-role"
    Environment = "development"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "s3_frontend_read" {
  name = "S3FrontendBuildRead"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::${var.frontend_bucket_name}",
        "arn:aws:s3:::${var.frontend_bucket_name}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ha-project-ec2-frontend-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_launch_template" "lt" {
  name_prefix   = "ha-project-lt"
  image_id      = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    security_groups = [var.ec2_sg_id]
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh.tpl", {
    frontend_bucket = var.frontend_bucket_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ha-project-frontend"
    }
  }

  # IMPORTANT FOR DEMO:
  # We deliberately do NOT ignore user_data changes.
  # Every time you change this file (or the .tpl) and run Terraform apply
  # via the GitHub workflow, a new Launch Template version is published.
  # The ASG ($Latest) + Instance Refresh then brings up fresh instances
  # with the new user-data (early placeholder + React from S3).
  # This is what makes "the site shows again" after fixes.
  #
  # After your presentation you can add the ignore_changes block back if desired.
}