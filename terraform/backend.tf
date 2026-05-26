terraform {
  backend "s3" {
    bucket         = "aws-ha-terraform-state-bucket"   # ← Change this to your actual bucket
    key            = "ha-3tier/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}