variable "aws_region" {
  description = "AWS region. Confirm the selected AMI, instance types, and EBS options are available here."
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile authenticated to the target account."
  type        = string
  default     = "assignment"
}

variable "aws_account_id" {
  description = "Expected AWS account ID; prevents accidentally using a different account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id)) && var.aws_account_id != "000000000000"
    error_message = "Set the real 12-digit AWS account ID; the placeholder is not deployable."
  }
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

variable "ami_id" {
  description = "Region-specific, current Linux AMI ID. Supply a valid AMI for the target region."
  type        = string
}

variable "private_subnet_ids" {
  description = "At least two private subnet IDs in distinct Availability Zones."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2 && length(distinct(var.private_subnet_ids)) == length(var.private_subnet_ids)
    error_message = "Supply at least two different private subnet IDs."
  }
}

variable "security_group_ids" {
  description = "Explicitly reviewed security groups for the instances."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "At least one explicitly reviewed security group is required."
  }
}

variable "instance_profile_name" {
  description = "Existing least-privilege instance profile for the EC2 workloads."
  type        = string

  validation {
    condition     = length(trimspace(var.instance_profile_name)) > 0
    error_message = "An EC2 instance profile is required; do not use static AWS credentials."
  }
}

variable "protected_instance_name" {
  description = "Key in instances whose EC2 resource has prevent_destroy enabled."
  type        = string
  default     = "production-db"
}

variable "enable_assignment_ssh_key_pairs" {
  description = "Attach assignment SSH key pairs. Keep false in production and use Systems Manager."
  type        = bool
  default     = false
}

variable "instances" {
  description = "Exactly five differently configured EC2 instances keyed by their Name tag."
  type = map(object({
    instance_type = string
    volume_type   = string
    volume_size   = number
    volume_iops   = optional(number)
    key_name      = optional(string)
  }))

  validation {
    condition     = length(var.instances) == 5
    error_message = "Provide exactly five instance configurations."
  }

  validation {
    condition     = contains(keys(var.instances), var.protected_instance_name)
    error_message = "protected_instance_name must match one of the five instance map keys."
  }

  validation {
    condition = alltrue([
      for config in values(var.instances) :
      contains(["gp2", "gp3", "io1", "io2", "standard"], config.volume_type) &&
      config.volume_size > 0 &&
      length(trimspace(config.instance_type)) > 0 &&
      (!var.enable_assignment_ssh_key_pairs || (config.key_name != null && length(trimspace(config.key_name)) > 0)) &&
      (contains(["io1", "io2"], config.volume_type) ? (config.volume_iops == null ? false : config.volume_iops > 0) : config.volume_iops == null)
    ])
    error_message = "Provide non-empty instance names, positive volume sizes, and IOPS only for io1/io2 volumes; SSH key names are required only when enabled."
  }

  validation {
    condition = (
      length(distinct([for config in values(var.instances) : config.instance_type])) == 5 &&
      length(distinct([for config in values(var.instances) : config.volume_type])) == 5 &&
      length(distinct([for config in values(var.instances) : config.volume_size])) == 5 &&
      (!var.enable_assignment_ssh_key_pairs || length(distinct([for config in values(var.instances) : config.key_name])) == 5)
    )
    error_message = "Each instance must use a distinct instance type, root volume type, volume size, and (when enabled) key pair."
  }

  validation {
    condition = var.enable_assignment_ssh_key_pairs ? alltrue([
      for config in values(var.instances) :
      config.key_name == null ? false : length(trimspace(config.key_name)) > 0
    ]) : true
    error_message = "When assignment SSH keys are enabled, each instance must specify a key-pair name."
  }
}
