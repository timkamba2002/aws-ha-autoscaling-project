module "vpc" {
  source = "./modules/vpc"
  create = var.environment == "development"
  vpc_id = var.environment == "development" ? "" : "vpc-0d4035555d90998ca"
}

module "security_groups" {
  source = "./modules/security-groups"
  vpc_id = var.environment == "development" ? module.vpc.vpc_id : "vpc-0d4035555d90998ca"
  create = var.environment == "development"
}

module "alb" {
  source            = "./modules/alb"
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  vpc_id            = var.environment == "development" ? module.vpc.vpc_id : "vpc-0d4035555d90998ca"
  create            = var.environment == "development"
}

module "ec2" {
  source               = "./modules/ec2"
  ec2_sg_id            = module.security_groups.ec2_sg_id
  frontend_bucket_name = var.frontend_builds_bucket
  environment          = var.environment
  frontend_s3_prefix   = var.frontend_s3_prefix
}

module "autoscaling" {
  source             = "./modules/autoscaling"
  private_subnet_ids = module.vpc.private_subnet_ids
  launch_template_id = module.ec2.launch_template_id
  target_group_arn   = module.alb.target_group_arn
  create_asg         = var.environment == "development"
}

# S3 bucket for React frontend build artifacts (uploaded by GitHub Actions, downloaded by EC2 on boot)
# Only created/managed in development state; staging/prod reuse the existing bucket (different prefix in user-data)
resource "aws_s3_bucket" "frontend_builds" {
  count = var.environment == "development" ? 1 : 0

  bucket = var.frontend_builds_bucket

  tags = {
    Name        = "HA Project Frontend Builds"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_builds" {
  count = var.environment == "development" ? 1 : 0

  bucket = aws_s3_bucket.frontend_builds[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "frontend_builds" {
  count = var.environment == "development" ? 1 : 0

  bucket = aws_s3_bucket.frontend_builds[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# ==================== MONITORING (CloudWatch Logs + Alarms) ====================
# Simple SNS topic for alarm notifications (email subscription can be added manually in console or via additional resource)
resource "aws_sns_topic" "alarms" {
  name = "${var.environment}-ha-project-alarms"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "monitoring" {
  source = "./modules/monitoring"

  environment                      = var.environment
  backend_log_group_name           = "/aws/ec2/ha-project-${var.environment}-backend"
  rds_instance_identifier          = try(aws_db_instance.main[0].identifier, "myapp-rds")
  rds_cpu_threshold                = 80
  rds_free_storage_threshold_bytes = 5 * 1024 * 1024 * 1024 # 5 GB
  alarm_sns_topic_arn              = aws_sns_topic.alarms.arn
  enable_connection_alarm          = true
  rds_max_connections_threshold    = 80
  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
