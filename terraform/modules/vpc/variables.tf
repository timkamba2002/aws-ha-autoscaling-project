variable "create" {
  description = "Whether to create the VPC and associated networking resources (true only for development; false for staging/production to reuse the shared dev ones)"
  type        = bool
  default     = true
}
