variable "create" {
  description = "Whether to create the VPC and associated networking resources (true only for development; false for staging/production to reuse the shared dev ones). 'state + create = true' means: this particular Terraform state (e.g. the development one) is the owner and will actually provision the network in AWS."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "The ID of the live VPC (vpc-0d4035555d90998ca) to use when create=false (staging/prod reuse). Empty string for development (we create the VPC ourselves)."
  type        = string
  default     = ""
}
