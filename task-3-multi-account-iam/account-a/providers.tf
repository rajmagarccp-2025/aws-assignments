provider "aws" {
  region              = var.aws_region
  profile             = var.aws_profile
  allowed_account_ids = [var.account_a_id]

  default_tags {
    tags = {
      Environment = var.environment
      Owner       = var.owner
    }
  }
}
