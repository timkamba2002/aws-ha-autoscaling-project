variable "db_password" {
  description = "Fallback password for RDS (SSM parameter takes priority)"
  type        = string
  sensitive   = true
  default     = null
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "frontend_builds_bucket" {
  description = "S3 bucket name for React frontend build artifacts (uploaded by CI, pulled by EC2 user-data)"
  type        = string
  default     = "ha-project-frontend-builds"
}

variable "frontend_s3_prefix" {
  description = "S3 prefix under the bucket for this environment's frontend build (e.g. current for dev, staging, production)"
  type        = string
  default     = "current"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

# RDS / PostgreSQL
variable "rds_identifier" {
  description = "RDS instance identifier (use different name from any existing MySQL)"
  type        = string
  default     = "ha-project-postgres"
}

variable "postgres_version" {
  type    = string
  default = "15.7"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "tododb"
}

variable "db_username" {
  type    = string
  default = "todouser"
}

variable "alarm_sns_topic_arn" {
  description = "Optional SNS topic for CloudWatch alarm notifications"
  type        = string
  default     = null
}
