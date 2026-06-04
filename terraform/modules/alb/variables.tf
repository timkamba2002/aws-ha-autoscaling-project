variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "vpc_id" {
  description = "VPC ID (required when create=true for the target group; passed but unused when create=false)"
  type        = string
}

variable "create" {
  description = "Whether to create the ALB/TG/Listener (true only for development)"
  type        = bool
  default     = true
}
