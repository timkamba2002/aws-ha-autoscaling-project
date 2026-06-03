variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "create" {
  description = "Whether to create the ALB/TG/Listener (true only for development)"
  type        = bool
  default     = true
}
