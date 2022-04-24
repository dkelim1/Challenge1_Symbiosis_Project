# Define Local Values in Terraform
locals {
  owners      = var.business_divsion
  environment = terraform.workspace

  common_tags = {
    owners      = local.owners
    environment = local.environment
  }
} 