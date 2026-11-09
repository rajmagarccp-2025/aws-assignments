output "state_bucket_name" {
  description = "S3 bucket name to place in the backend configuration."
  value       = module.terraform_state_bucket.id
}

output "lock_table_name" {
  description = "DynamoDB table name to place in the backend configuration."
  value       = aws_dynamodb_table.terraform_lock.name
}
