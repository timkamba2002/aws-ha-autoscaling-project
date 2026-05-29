module "vpc" {
  source = "./modules/vpc"
}

module "security_groups" {
  source = "./modules/security-groups"
  vpc_id = module.vpc.vpc_id
}

module "alb" {
  source            = "./modules/alb"
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  vpc_id            = module.vpc.vpc_id
}

module "ec2" {
  source               = "./modules/ec2"
  ec2_sg_id            = module.security_groups.ec2_sg_id
  frontend_bucket_name = var.frontend_builds_bucket
}

module "autoscaling" {
  source             = "./modules/autoscaling"
  private_subnet_ids = module.vpc.private_subnet_ids
  launch_template_id = module.ec2.launch_template_id
  target_group_arn   = module.alb.target_group_arn
}

# S3 bucket for React frontend build artifacts (uploaded by GitHub Actions, downloaded by EC2 on boot)
resource "aws_s3_bucket" "frontend_builds" {
  bucket = var.frontend_builds_bucket

  tags = {
    Name        = "HA Project Frontend Builds"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_builds" {
  bucket = aws_s3_bucket.frontend_builds.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "frontend_builds" {
  bucket = aws_s3_bucket.frontend_builds.id
  versioning_configuration {
    status = "Enabled"
  }
}
