terraform {
  backend "s3" {
    bucket         = "aws-ha-terraform-state-bucket"   # ← CHANGE THIS to your actual bucket name
    key            = "ha-3tier/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    # DynamoDB locking disabled temporarily due to permission issues
    # dynamodb_table = "terraform-state-lock"
  }
}