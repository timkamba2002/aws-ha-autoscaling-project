variable "ec2_sg_id" {
  type = string
}

variable "frontend_bucket_name" {
  description = "S3 bucket name that stores the React frontend build artifacts (current/ folder)"
  type        = string
  default     = "ha-project-frontend-builds"
}
