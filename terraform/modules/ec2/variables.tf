variable "ec2_sg_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}

variable "frontend_bucket_name" {
  description = "S3 bucket name for React frontend build artifacts (uploaded by CI, pulled by EC2 user-data)"
  type        = string
  default     = "ha-project-frontend-builds"
}
