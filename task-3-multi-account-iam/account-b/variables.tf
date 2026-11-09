variable "aws_region" {
  description = "AWS region for Account B resources."
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile authenticated to Account B."
  type        = string
  default     = "account-b"
}

variable "account_a_id" {
  description = "Account A ID; replace the placeholder before planning."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_a_id)) && var.account_a_id != "000000000000"
    error_message = "Set the real 12-digit Account A ID; the placeholder is not deployable."
  }
}

variable "account_b_id" {
  description = "Account B ID; replace the placeholder before planning."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_b_id)) && var.account_b_id != "111111111111" && var.account_b_id != var.account_a_id
    error_message = "Set the real 12-digit Account B ID; the placeholder is not deployable."
  }
}

variable "production_bucket_name" {
  description = "Globally unique S3 bucket name dedicated to roleC."
  type        = string
  default     = "company-production-data"
}

variable "enable_assignment_full_s3_access" {
  description = "Enable the assignment's broad s3:* access for roleC. Keep false for production."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "assignment"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "devops-assignment"
}
