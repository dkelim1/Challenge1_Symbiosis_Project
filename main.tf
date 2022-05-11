# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE ALL THE RESOURCES TO DEPLOY AN APP IN AN AUTO SCALING GROUP WITH AN ELB
# This project runs a simple NodeJS application in Auto Scaling Group (ASG) with an Elastic Load Balancer
# It connects to a MySQL database to add/modify user' s age and email etc.  
# (ELB) in front of it to distribute traffic across the EC2 Instances in the ASG.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "< 4.0"
    }
  }

  backend "s3" {
    bucket = "dl-symbiosis-tf-state"
    key    = "project/symbiosis_tf/terraform.tfstate"
    region = "ap-southeast-1"

    dynamodb_table = "dl-symbiosis-tf-state-locking"
  }

}

# ------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ------------------------------------------------------------------------------

provider "aws" {
  region = "ap-southeast-1"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# QUERY AWS SECRETS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Importing the AWS secrets created previously using id.


data "aws_secretsmanager_secret" "db_creds" {
  arn = aws_secretsmanager_secret.db_creds.id
}

# Importing the AWS secret version created previously using id.

data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = data.aws_secretsmanager_secret.db_creds.id
}


# ------------------------------------------------------------------------------
# PREPARES THE EC2 INSTANCES TERMPLATE FOR LAUNCHING
# ------------------------------------------------------------------------------

data "template_file" "backend_cloud_init" {
  template = file("cloud_init/cloud_init.sh")
  vars = {
    DB_HOST   = aws_db_instance.mysql_rds.address,
    DB_USER   = local.db_creds.db_username,
    DB_PASSWD = local.db_creds.db_password,
    DB_NAME   = aws_db_instance.mysql_rds.name,
    DB_PORT   = aws_db_instance.mysql_rds.port
  }
}

# ------------------------------------------------------------------------------
# QUERIES THE AMI IN THE REGION AVAILABLE FOR USE
# ------------------------------------------------------------------------------

data "aws_ami" "amzlinux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-gp2"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE AWS SECRETS
# This resources creates a AWS secret depends on the environment the user is in.  Both db_username and db_password is managed 
# under secrets manager.  
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "#*^_-"
}

# Creating a AWS secret for database master account (Masteraccoundb)

resource "aws_secretsmanager_secret" "db_creds" {
  name_prefix             = "${terraform.workspace}-db-creds"
  recovery_window_in_days = 0
}

# Creating a AWS secret versions for database master account (Masteraccoundb)

resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id     = aws_secretsmanager_secret.db_creds.id
  secret_string = <<EOF
   {
    "db_username": "admin",
    "db_password": "${random_password.password.result}"
   }
  EOF
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE BASTION HOST FOR PERFORMING TROUBLESHOOTING OR MANUAL HEALTH CHECK
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_instance" "bastion_host" {
  depends_on = [module.vpc]

  ami                    = data.aws_ami.amzlinux2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.bastion_host_sg.id]
  key_name               = var.instance_keypair
  subnet_id              = module.vpc.public_subnets[0]

  user_data = file("${path.module}/cloud_init/software-install.sh")

  provisioner "file" {
    connection {
      user        = "ec2-user"
      host        = aws_instance.bastion_host.public_dns
      private_key  = file("${path.module}/private-key/terraform-key.pem")
    }

    source      = "./private-key/terraform-key.pem"
    destination = "/home/ec2-user/.ssh/terraform-key.pem"
  }

  provisioner "remote-exec" {
    connection {
      user        = "ec2-user"
      host        = aws_instance.bastion_host.public_dns
      private_key  = file("${path.module}/private-key/terraform-key.pem")
    }

    inline = [
      "chmod 600 /home/ec2-user/.ssh/terraform-key.pem"
    ]
  }

  tags = {
    Name = "symbios-${terraform.workspace}-bastion-host"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAUNCH CONFIGURATION THAT DEFINES EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "webapps_lc" {

  depends_on      = [module.vpc, aws_db_instance.mysql_rds]
  name_prefix     = "symbios-webapps-${terraform.workspace}-lc"
  image_id        = data.aws_ami.amzlinux2.id
  instance_type   = module.vars.env.apps_instance_type
  security_groups = [aws_security_group.apps_instance_sg.id]
  key_name        = var.instance_keypair

  user_data = data.template_file.backend_cloud_init.rendered


  # Whenever using a launch configuration with an auto scaling group, you must set create_before_destroy = true.
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  lifecycle {
    create_before_destroy = true
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_autoscaling_group" "webapps_asg" {

  name_prefix          = "symbios-webapps-${terraform.workspace}-asg"
  launch_configuration = aws_launch_configuration.webapps_lc.id
  vpc_zone_identifier  = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]

  //desired_capacity = module.vars.env.desired_capacity
  min_size = module.vars.env.min_size
  max_size = module.vars.env.max_size

  load_balancers    = [aws_elb.webapps_elb.name]
  health_check_type = "EC2"
  wait_for_elb_capacity = module.vars.env.min_size

  tag {
    key                 = "Name"
    value               = "symbios-webapps-asg"
    propagate_at_launch = true
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE AUTO SCALING POLICY BASED ON AVERAGE CPU UTILIZATION
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_autoscaling_policy" "cpu" {
  autoscaling_group_name = aws_autoscaling_group.webapps_asg.name
  name                   = "cpu"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = module.vars.env.target_value
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ELB TO ROUTE TRAFFIC ACROSS THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_elb" "webapps_elb" {
  depends_on      = [module.vpc]
  name            = "webapps-${terraform.workspace}-elb"
  security_groups = [aws_security_group.elb_sg.id]
  subnets         = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]

  health_check {
    target              = "HTTP:${var.nodejs_port}/"
    interval            = 30
    timeout             = 25
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }

  # This adds a listener for incoming HTTP requests.
  listener {
    lb_port           = var.elb_port
    lb_protocol       = "http"
    instance_port     = var.nodejs_port
    instance_protocol = "http"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP THAT CONTROLS WHAT TRAFFIC AN GO IN AND OUT OF THE ELB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "elb_sg" {
  name   = "elb-${terraform.workspace}-sg"
  vpc_id = module.vpc.vpc_id

  # Inbound HTTP from anywhere
  ingress {
    from_port   = var.elb_port
    to_port     = var.elb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP THAT CONTROLS WHAT TRAFFIC AN GO IN AND OUT OF THE BASTION HOST
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "bastion_host_sg" {
  name   = "bastion-host-${terraform.workspace}-sg"
  vpc_id = module.vpc.vpc_id

  # Inbound SSH from anywhere
  ingress {
    from_port = var.ssh_port
    to_port   = var.ssh_port
    protocol  = "tcp"
    ## Change to specific IP launched from a secure location 
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE SECURITY GROUP THAT'S APPLIED TO EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "apps_instance_sg" {
  name   = "apps-instance-${terraform.workspace}-sg"
  vpc_id = module.vpc.vpc_id

  # Inbound HTTP from ELB and bastion host
  ingress {
    from_port       = var.nodejs_port
    to_port         = var.nodejs_port
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_sg.id]
  }

  ingress {
    from_port       = var.ssh_port
    to_port         = var.ssh_port
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_host_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE SECURITY GROUP THAT'S APPLIED TO THE MYSQL RDS DB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "mysqldb_sg" {

  name   = "mysqldb-${terraform.workspace}-sg"
  vpc_id = module.vpc.vpc_id

  # Inbound HTTP from EC2 ASG and bastion host
  ingress {
    from_port       = var.mysqldb_port
    to_port         = var.mysqldb_port
    protocol        = "tcp"
    security_groups = [aws_security_group.apps_instance_sg.id]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE MYSQL RDS DB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_instance" "mysql_rds" {

  identifier_prefix      = "mysql-rds-${terraform.workspace}"
  engine                 = "mysql"
  allocated_storage      = module.vars.env.db_allocated_storage
  instance_class         = module.vars.env.db_instance_class
  name                   = var.db_name
  username               = local.db_creds.db_username
  password               = local.db_creds.db_password
  multi_az               = module.vars.env.db_multi_az
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.mysqldb_sg.id]

  # Don't copy this to your production examples. It's only here to make it quicker to delete this DB.
  skip_final_snapshot = true

}


