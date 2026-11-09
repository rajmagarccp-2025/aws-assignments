variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile authenticated to Account A."
  type        = string
  default     = "account-a"
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

variable "console_login_pgp_key" {
  description = "Base64-encoded PGP public key used to encrypt generated console passwords."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = !var.enable_assignment_iam_users || (var.console_login_pgp_key != null && length(trimspace(var.console_login_pgp_key)) > 0)
    error_message = "A PGP public key is required when assignment IAM users and console profiles are enabled."
  }
}

variable "enable_assignment_iam_users" {
  description = "Create the assignment's IAM users and group memberships. Keep false and use IAM Identity Center in production."
  type        = bool
  default     = false
}

variable "enable_assignment_iam_access_keys" {
  description = "Create long-lived keys for assignment IAM users. Keys are stored in Terraform state; keep false outside an isolated sandbox."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_assignment_iam_access_keys || var.enable_assignment_iam_users
    error_message = "Assignment access keys require enable_assignment_iam_users = true."
  }
}

variable "enable_assignment_role_a_broad_permissions" {
  description = "Enable the assignment's broad non-IAM permissions for roleA. Keep false in production."
  type        = bool
  default     = false
}

variable "ci_ecr_repository_name" {
  description = "ECR repository the ci user may push images to."
  type        = string
  default     = "assignment-app"
}

variable "ci_ecs_cluster_name" {
  description = "ECS cluster containing the deployment service."
  type        = string
  default     = "assignment-cluster"
}

variable "ci_ecs_service_name" {
  description = "Single ECS service the ci user may update."
  type        = string
  default     = "assignment-service"
}

variable "ci_ecs_task_family" {
  description = "Task-definition family the ci user may register."
  type        = string
  default     = "assignment-app"
}

variable "ci_task_execution_role_name" {
  description = "Existing task execution role that the ci user may pass to ECS."
  type        = string
  default     = "assignment-task-execution"
}

variable "ci_task_role_name" {
  description = "Existing application task role that the ci user may pass to ECS."
  type        = string
  default     = "assignment-task"
}

variable "ci_build_artifacts_bucket" {
  description = "S3 bucket from which the ci user may read build artifacts."
  type        = string
  default     = "replace-with-build-artifacts-bucket"
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
