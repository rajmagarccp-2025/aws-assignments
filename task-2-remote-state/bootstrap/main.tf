module "terraform_state_bucket" {
  source = "../../modules/secure-s3-bucket"

  bucket_name = var.state_bucket_name
  kms_key_arn = var.state_kms_key_arn
  tags = {
    Name        = "terraform-state"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_dynamodb_table" "terraform_lock" {
  name                        = var.lock_table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "LockID"
  deletion_protection_enabled = true

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = var.lock_table_name
    Environment = var.environment
    Owner       = var.owner
  }

  lifecycle {
    prevent_destroy = true
  }
}
