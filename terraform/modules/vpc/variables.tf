variable "create" {
  description = "Whether to create the VPC and associated networking resources (true only for development; false for staging/production to reuse the shared dev ones)"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "The ID of the live VPC to use when create=false (e.g. vpc-0d4035555d90998ca for staging/prod)"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "ID of the existing VPC to use when create=false (the live one from development)"
  type        = string
  default     = ""
}
