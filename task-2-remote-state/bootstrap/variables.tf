variable "aws_region" {
  description = "Region used for the state bucket and lock table."
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile authorized to bootstrap the state resources."
  type        = string
  default     = "assignment"
}

variable "aws_account_id" {
  description = "Expected AWS account ID."
  type        = string
  default     = "000000000000"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id)) && var.aws_account_id != "000000000000"
    error_message = "Set the real 12-digit AWS account ID; the placeholder is not deployable."
  }
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "Use a real globally unique S3 bucket name with valid DNS-compatible characters."
  }
}

variable "state_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for state-bucket encryption."
  type        = string
  default     = null
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking."
  type        = string
  default     = "terraform-state-lock"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "shared"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "devops-assignment"
}
