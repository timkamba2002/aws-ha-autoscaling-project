variable "db_password" {
  description = "Password for RDS database"
  type        = string
  sensitive   = true
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

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}
