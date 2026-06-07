terraform {
  backend "s3" {
    # Using S3 native locking (recommended for Terraform >= 1.10)
    bucket       = "ha-project-terraform-state-866934333672"
    key          = "ha-project/development/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
