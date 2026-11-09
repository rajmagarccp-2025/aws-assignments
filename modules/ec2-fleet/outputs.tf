locals {
  all_instances = merge(
    { for name, instance in aws_instance.protected : name => instance },
    { for name, instance in aws_instance.regular : name => instance }
  )
}

output "instance_ids" {
  description = "Map of instance Name tags to EC2 instance IDs."
  value       = { for name, instance in local.all_instances : name => instance.id }
}

output "private_ip_addresses" {
  description = "Map of instance Name tags to private IP addresses."
  value       = { for name, instance in local.all_instances : name => instance.private_ip }
}
