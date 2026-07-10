terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket  = "tomario-tfstate-nonprod"
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

# CloudFront経由のリクエストであることをALBが検証するためのシークレットヘッダー値（SEC-7）
resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

module "network" {
  source = "../../../modules/network"

  env                  = var.env
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}

module "backend" {
  source = "../../../modules/backend"

  env                        = var.env
  vpc_id                     = module.network.vpc_id
  public_subnet_ids          = module.network.public_subnet_ids
  private_subnet_ids         = module.network.private_subnet_ids
  db_host                    = module.database.rds_address
  db_secret_arn              = module.database.master_user_secret_arn
  rds_sg_id                  = module.database.rds_sg_id
  origin_verify_header_value = random_password.origin_verify.result
}

module "database" {
  source = "../../../modules/database"

  env                = var.env
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
}

module "frontend" {
  source = "../../../modules/frontend"

  env                        = var.env
  alb_dns_name               = module.backend.alb_dns_name
  origin_verify_header_value = random_password.origin_verify.result
}

module "monitoring" {
  source = "../../../modules/monitoring"

  env                     = var.env
  alarm_email             = var.alarm_email
  alb_arn_suffix          = module.backend.alb_arn_suffix
  target_group_arn_suffix = module.backend.target_group_arn_suffix
  ecs_service_name        = module.backend.ecs_service_name
  db_instance_identifier  = module.database.db_instance_identifier
}
