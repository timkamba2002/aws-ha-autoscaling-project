resource "aws_iam_role" "ec2_role" {
  count = var.environment == "development" ? 1 : 0
  name  = "ha-project-ec2-frontend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  # We use count + lifecycle ignore to support shared global role name across env-specific TF states.
  # Only the development state creates/manages the role.
  # Other env applies (staging/prod) use the existing role by name in the launch template.
  # ignore_changes on tags prevents UntagRole/TagRole calls that the limited OIDC deploy role cannot perform.
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_iam_role_policy" "s3_frontend_read" {
  count = var.environment == "development" ? 1 : 0
  name  = "S3FrontendBuildRead"
  role  = "ha-project-ec2-frontend-role"

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

# Allow EC2 instances to read DB credentials from SSM Parameter Store.
# This was previously commented out because the GitHub OIDC role lacked
# iam:PutRolePolicy permission. Now that permissions are restored on the
# human IAM user, this can be applied cleanly from Terraform.
resource "aws_iam_role_policy" "ssm_read_db_creds" {
  count = var.environment == "development" ? 1 : 0
  name  = "SSMReadDBCredentials"
  role  = "ha-project-ec2-frontend-role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      Resource = [
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/development/db_password",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/development/db_host",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/development/db_user",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/staging/db_password",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/staging/db_host",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/staging/db_user",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/production/db_password",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/production/db_host",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/production/db_user"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  count = var.environment == "development" ? 1 : 0
  name  = "ha-project-ec2-frontend-profile"
  role  = "ha-project-ec2-frontend-role"
}

resource "aws_launch_template" "lt" {
  name_prefix   = "ha-project-lt"
  image_id      = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type = "t2.micro"

  iam_instance_profile {
    # Always use the fixed profile name. The profile resource is only created in the "development" state
    # (see count on aws_iam_instance_profile), but the name is the same everywhere.
    # Other env states rely on the role/profile having been created by a prior dev apply.
    name = "ha-project-ec2-frontend-profile"
  }

  network_interfaces {
    security_groups = [var.ec2_sg_id]
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh.tpl", {
    frontend_bucket = var.frontend_bucket_name
    frontend_prefix = var.frontend_s3_prefix
    environment     = var.environment
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