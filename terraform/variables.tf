# variable "db_password" {
#   description = "Password for RDS database"
#   type        = string
#   sensitive   = true
# }

# Add any other variables you might need here
variable "region" {
  default = "us-east-1"
}