module "ec2_fleet" {
  source = "../modules/ec2-fleet"

  ami_id                          = var.ami_id
  private_subnet_ids              = var.private_subnet_ids
  security_group_ids              = var.security_group_ids
  instance_profile_name           = var.instance_profile_name
  environment                     = var.environment
  owner                           = var.owner
  protected_instance_name         = var.protected_instance_name
  enable_assignment_ssh_key_pairs = var.enable_assignment_ssh_key_pairs
  instances                       = var.instances
}
