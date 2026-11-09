variable "ami_id" {
  description = "Region-specific AMI ID."
  type        = string
}

variable "private_subnet_ids" {
  description = "At least two existing private subnet IDs in distinct Availability Zones."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2 && length(distinct(var.private_subnet_ids)) == length(var.private_subnet_ids)
    error_message = "Supply at least two different private subnet IDs."
  }
}

variable "security_group_ids" {
  description = "Reviewed security groups. Empty/default groups are not permitted."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "At least one explicitly reviewed security group is required."
  }
}

variable "instance_profile_name" {
  description = "Existing least-privilege EC2 instance profile for workload access."
  type        = string

  validation {
    condition     = length(trimspace(var.instance_profile_name)) > 0
    error_message = "An EC2 instance profile is required; do not use static AWS credentials."
  }
}

variable "environment" {
  description = "Environment tag."
  type        = string
}

variable "owner" {
  description = "Owner tag."
  type        = string
}

variable "protected_instance_name" {
  description = "Instance map key protected from Terraform destroy."
  type        = string
}

variable "enable_assignment_ssh_key_pairs" {
  description = "Attach the assignment's SSH key pairs. Keep false and use Systems Manager in production."
  type        = bool
}

variable "instances" {
  description = "Instance configurations keyed by Name tag."
  type = map(object({
    instance_type = string
    volume_type   = string
    volume_size   = number
    volume_iops   = optional(number)
    key_name      = optional(string)
  }))

  validation {
    condition = var.enable_assignment_ssh_key_pairs ? (
      alltrue([
        for config in values(var.instances) :
        config.key_name == null ? false : length(trimspace(config.key_name)) > 0
      ]) &&
      length(distinct([for config in values(var.instances) : config.key_name])) == length(var.instances)
    ) : true
    error_message = "When assignment SSH keys are enabled, give every instance a distinct non-empty key-pair name."
  }
}
