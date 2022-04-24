#
# Fetch variables based on Environment
#
module "vars" {
  source      = "./modules/vars"
  environment = local.environment
}


# Create VPC Terraform Module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  #version = "2.78.0"
  version = "3.0.0"

  # VPC Basic Details
  name            = lookup(var.vpc_name, terraform.workspace)
  cidr            = lookup(var.vpc_cidr_block, terraform.workspace)
  azs             = var.vpc_availability_zones
  public_subnets  = lookup(var.vpc_public_subnets, terraform.workspace)
  private_subnets = lookup(var.vpc_private_subnets, terraform.workspace)

  # Database Subnets
  database_subnets                   = lookup(var.vpc_database_subnets, terraform.workspace)
  create_database_subnet_group       = var.vpc_create_database_subnet_group
  create_database_subnet_route_table = var.vpc_create_database_subnet_route_table
  # create_database_internet_gateway_route = true
  # create_database_nat_gateway_route = true


  # NAT Gateways - Outbound Communication
  enable_nat_gateway = var.vpc_enable_nat_gateway
  single_nat_gateway = var.vpc_single_nat_gateway


  # VPC DNS Parameters
  enable_dns_hostnames = true
  enable_dns_support   = true


  tags     = local.common_tags
  vpc_tags = local.common_tags

  # Additional Tags to Subnets
  public_subnet_tags = {
    Type = "Public Subnets"
  }
  private_subnet_tags = {
    Type = "Private Subnets"
  }
  database_subnet_tags = {
    Type = "Private Database Subnets"
  }
}
