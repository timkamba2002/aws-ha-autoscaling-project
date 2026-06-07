variable "environment" {
  type    = string
  default = "development"
}

variable "backend_log_group_name" {
  description = "Name of the CloudWatch Log Group for the backend app"
  type        = string
  default     = "/aws/ec2/ha-project-backend"
}

variable "log_retention_days" {
  type    = number
  default = 90   # Raised from 14 to address CKV_AWS_338 (Checkov wants >=365 for strict compliance; 90 is a reasonable demo compromise)
}

variable "rds_instance_identifier" {
  description = "The DB instance identifier for RDS alarms"
  type        = string
}

variable "rds_cpu_threshold" {
  type    = number
  default = 80
}

variable "rds_free_storage_threshold_bytes" {
  description = "Alarm when free storage drops below this many bytes (5GB = 5368709120)"
  type        = number
  default     = 5368709120
}

variable "rds_max_connections_threshold" {
  type    = number
  default = 80
}

variable "enable_connection_alarm" {
  type    = bool
  default = false
}

variable "alarm_sns_topic_arn" {
  description = "Optional SNS topic ARN for alarm notifications"
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
