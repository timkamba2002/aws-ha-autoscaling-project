terraform {
  backend "s3" {
    # IMPORTANT: This bucket and DynamoDB table must exist before running terraform init
    # See repair-commands.md for one-time AWS CLI setup commands
    bucket         = "ha-project-terraform-state-866934333672"
    key            = "ha-project/development/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ha-project-terraform-locks"
    encrypt        = true
  }
}
