# variable "db_password" {
#   description = "Password for RDS database"
#   type        = string
#   sensitive   = true
# }

# Add any other variables you might need here
variable "region" {
  default = "us-east-1"
}

variable "frontend_builds_bucket" {
  description = "Name of the S3 bucket that will hold React build artifacts uploaded by GitHub Actions"
  type        = string
  default     = "ha-project-frontend-builds"
}