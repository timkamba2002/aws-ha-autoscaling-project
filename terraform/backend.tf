terraform {
  backend "s3" {
    bucket = "aws-ha-terraform-state-bucket"
    key    = "ha-3tier/terraform.tfstate"
    region = "us-east-1"
  }
}
