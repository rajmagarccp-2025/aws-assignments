output "role_a_arn" {
  description = "Account A roleA ARN; broad assignment permissions are opt-in."
  value       = aws_iam_role.role_a.arn
}

output "role_b_arn" {
  description = "Account A cross-account access role ARN."
  value       = aws_iam_role.role_b.arn
}

output "assignment_user_access_keys" {
  description = "Sensitive one-time access key values for assignment users. Terraform state also contains these secrets."
  value = {
    for username, key in aws_iam_access_key.assignment_users : username => {
      access_key_id     = key.id
      secret_access_key = key.secret
    }
  }
  sensitive = true
}
