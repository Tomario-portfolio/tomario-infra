terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket  = "tomario-tfstate-shared-bucket"
    key     = "dev/terraform.tfstate"
    region  = "ap-northeast-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "tomario"
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }
}

module "network" {
  source = "../../modules/network"

  env                  = var.env
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}

module "backend" {
  source = "../../modules/backend"

  env               = var.env
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  instance_type     = "t3.micro"
}

module "database" {
  source = "../../modules/database"

  env                = var.env
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  ec2_sg_id          = module.backend.ec2_sg_id
}

module "frontend" {
  source = "../../modules/frontend"

  env          = var.env
  alb_dns_name = module.backend.alb_dns_name
}

module "monitoring" {
  source = "../../modules/monitoring"

  env                     = var.env
  alarm_email             = var.alarm_email
  alb_arn_suffix          = module.backend.alb_arn_suffix
  target_group_arn_suffix = module.backend.target_group_arn_suffix
  asg_name                = module.backend.asg_name
  db_instance_identifier  = module.database.db_instance_identifier
}
