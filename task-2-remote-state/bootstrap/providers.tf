provider "aws" {
  region              = var.aws_region
  profile             = var.aws_profile
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Name        = "terraform-state"
      Environment = var.environment
      Owner       = var.owner
    }
  }
}
