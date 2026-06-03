variable "vpc_id" {
  type = string
}

variable "create" {
  description = "Whether to create the security groups (true only for development)"
  type        = bool
  default     = true
}
