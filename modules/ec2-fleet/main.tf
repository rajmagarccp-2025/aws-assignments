locals {
  protected_instances = {
    for name, config in var.instances : name => config
    if name == var.protected_instance_name
  }
  regular_instances = {
    for name, config in var.instances : name => config
    if name != var.protected_instance_name
  }
}

data "aws_subnet" "private" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

resource "terraform_data" "validate_subnets" {
  input = var.private_subnet_ids

  lifecycle {
    precondition {
      condition = length(distinct([
        for subnet in data.aws_subnet.private : subnet.availability_zone
      ])) >= 2
      error_message = "EC2 fleet subnets must span at least two distinct Availability Zones."
    }
  }
}

resource "aws_instance" "protected" {
  for_each = local.protected_instances

  ami                         = var.ami_id
  instance_type               = each.value.instance_type
  key_name                    = var.enable_assignment_ssh_key_pairs ? each.value.key_name : null
  subnet_id                   = var.private_subnet_ids[index(keys(var.instances), each.key) % length(var.private_subnet_ids)]
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = false
  monitoring                  = true
  ebs_optimized               = true
  depends_on                  = [terraform_data.validate_subnets]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = each.value.volume_type
    volume_size           = each.value.volume_size
    iops                  = each.value.volume_iops
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_instance" "regular" {
  for_each = local.regular_instances

  ami                         = var.ami_id
  instance_type               = each.value.instance_type
  key_name                    = var.enable_assignment_ssh_key_pairs ? each.value.key_name : null
  subnet_id                   = var.private_subnet_ids[index(keys(var.instances), each.key) % length(var.private_subnet_ids)]
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = false
  monitoring                  = true
  ebs_optimized               = true
  depends_on                  = [terraform_data.validate_subnets]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = each.value.volume_type
    volume_size           = each.value.volume_size
    iops                  = each.value.volume_iops
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }
}
