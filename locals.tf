# Define Local Values in Terraform
locals {
  owners      = var.business_divsion
  environment = terraform.workspace

  common_tags = {
    owners      = local.owners
    environment = local.environment
  }

  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)
} 
