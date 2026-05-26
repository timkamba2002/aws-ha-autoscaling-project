terraform {
  backend "s3" {
    bucket         = "aws-ha-terraform-state-bucket"   # Create this bucket first
    key            = "aws-ha-autoscaling/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"         # Create this DynamoDB table
    encrypt        = true
  }
}
