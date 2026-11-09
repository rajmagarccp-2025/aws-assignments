output "instance_ids" {
  description = "Map of instance Name tags to EC2 instance IDs."
  value       = module.ec2_fleet.instance_ids
}

output "private_ip_addresses" {
  description = "Map of instance Name tags to private IP addresses."
  value       = module.ec2_fleet.private_ip_addresses
}
