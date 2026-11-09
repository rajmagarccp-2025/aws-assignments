output "role_c_arn" {
  description = "Account B role trusted only by Account A roleB."
  value       = aws_iam_role.role_c.arn
}

output "production_bucket_arn" {
  description = "Dedicated bucket whose contents are accessible to roleC."
  value       = module.production_data_bucket.arn
}
