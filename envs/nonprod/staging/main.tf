terraform {
  required_version = ">= 1.10"

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
    bucket       = "tomario-tfstate-nonprod"
    key          = "staging/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
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

# CloudFront経由のリクエストであることをALBが検証するためのシークレットヘッダー値（SEC-7、devと同じ）
resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

module "logging" {
  source = "../../../modules/logging"

  env                = var.env
  log_retention_days = 30
}

module "network" {
  source = "../../../modules/network"

  env                  = var.env
  vpc_cidr             = "10.1.0.0/16"
  azs                  = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnet_cidrs  = ["10.1.0.0/24", "10.1.1.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  logs_bucket_arn      = module.logging.bucket_arn
}

module "database" {
  source = "../../../modules/database"

  env                = var.env
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
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
  logs_bucket_id             = module.logging.bucket_id
  log_retention_days         = 30
  desired_count              = 2
  autoscaling_enabled        = true
  autoscaling_min_capacity   = 2
  autoscaling_max_capacity   = 4
  autoscaling_target_cpu     = 70
}

module "frontend" {
  source = "../../../modules/frontend"

  env                        = var.env
  alb_dns_name               = module.backend.alb_dns_name
  origin_verify_header_value = random_password.origin_verify.result
}
