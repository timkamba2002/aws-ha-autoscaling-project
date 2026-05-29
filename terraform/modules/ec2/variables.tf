variable "ec2_sg_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}

variable "frontend_bucket_name" {
  description = "S3 bucket name containing the React frontend builds"
  type        = string
}
