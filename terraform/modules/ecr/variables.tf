variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

variable "create" {
  description = "Whether to create ECR resources (true only for development to avoid cross-state conflicts)"
  type        = bool
  default     = true
}
