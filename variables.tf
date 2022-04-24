# Input Variables

# AWS Region
variable "aws_region" {
  description = "Region in which AWS Resources to be created"
  type        = string
  default     = "ap-southeast-1"
}

# Business Division
variable "business_divsion" {
  description = "Business Division in the large organization this Infrastructure belongs"
  type        = string
  default     = "symbiosis"
}

# VPC Name
variable "vpc_name" {
  description = "VPC Name"
  type        = map(any)
  default = {
    dev  = "symbiosis_vpc_dev",
    uat  = "symbiosis_vpc_uat",
    prod = "symbiosys_vpc_prod"
  }
}

# VPC CIDR Block
variable "vpc_cidr_block" {
  description = "VPC CIDR Block"
  type        = map(any)
  default = {
    dev  = "10.0.0.0/16",
    uat  = "10.1.0.0/16",
    prod = "10.2.0.0/16"
  }
}

# VPC Availability Zones
variable "vpc_availability_zones" {
  description = "VPC Availability Zones"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

# VPC Public Subnets
variable "vpc_public_subnets" {
  description = "VPC Public Subnets"
  type        = map(any)
  default = {
    dev  = ["10.0.101.0/24", "10.0.102.0/24"],
    uat  = ["10.1.101.0/24", "10.1.102.0/24"],
    prod = ["10.2.101.0/24", "10.2.102.0/24"]
  }
}

# VPC Private Subnets
variable "vpc_private_subnets" {
  description = "VPC Private Subnets"
  type        = map(any)
  default = {
    dev  = ["10.0.1.0/24", "10.0.2.0/24"],
    uat  = ["10.1.1.0/24", "10.1.2.0/24"],
    prod = ["10.2.1.0/24", "10.2.2.0/24"]
  }
}

# VPC Database Subnets
variable "vpc_database_subnets" {
  description = "VPC Database Subnets"
  type        = map(any)
  default = {
    dev  = ["10.0.121.0/24", "10.0.122.0/24"],
    uat  = ["10.1.121.0/24", "10.1.122.0/24"],
    prod = ["10.2.121.0/24", "10.2.122.0/24"]
  }
}

# VPC Create Database Subnet Group (True / False)
variable "vpc_create_database_subnet_group" {
  description = "VPC Create Database Subnet Group"
  type        = bool
  default     = true
}

# VPC Create Database Subnet Route Table (True or False)
variable "vpc_create_database_subnet_route_table" {
  description = "VPC Create Database Subnet Route Table"
  type        = bool
  default     = true
}

# VPC Enable NAT Gateway (True or False) 
variable "vpc_enable_nat_gateway" {
  description = "Enable NAT Gateways for Private Subnets Outbound Communication"
  type        = bool
  default     = true
}

# VPC Single NAT Gateway (True or False)
variable "vpc_single_nat_gateway" {
  description = "Enable only single NAT Gateway in one Availability Zone to save costs during our demos"
  type        = bool
  default     = true
}

# ELB port
variable "elb_port" {
  description = "The port the ELB will use for HTTP requests"
  type        = number
  default     = 80
}

# Application port
variable "nodejs_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 3000
}

# SSH port
variable "ssh_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 22
}

# MySQL port
variable "mysqldb_port" {
  description = "The port the ELB will use for HTTP requests"
  type        = number
  default     = 3306
}

# DB name
variable "db_name" {
  description = "The name for the database"
  type        = string
  default     = "symbiosdb"
}

# SSH keypair name
variable "instance_keypair" {
  description = "AWS EC2 Key pair that need to be associated with EC2 Instance"
  type        = string
  default     = "terraform-key"
}
