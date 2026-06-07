variable "private_subnet_ids" {
  type = list(string)
}

variable "launch_template_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "create_asg" {
  description = "Whether to create the ASG (true only for development)"
  type        = bool
  default     = true
}
