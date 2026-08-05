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
    key          = "dev/terraform.tfstate"
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

# CloudFront経由のリクエストであることをALBが検証するためのシークレットヘッダー値（SEC-7）
resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

# state分割（コンポーネント単位）でlogging用stateを独立させたため、リモートで参照する
data "terraform_remote_state" "logging" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-nonprod"
    key    = "dev/logging/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-nonprod"
    key    = "dev/network/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "backend" {
  source = "../../../modules/backend"

  env                        = var.env
  vpc_id                     = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids          = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_ids         = data.terraform_remote_state.network.outputs.private_subnet_ids
  db_host                    = module.database.rds_address
  db_secret_arn              = module.database.master_user_secret_arn
  rds_sg_id                  = module.database.rds_sg_id
  origin_verify_header_value = random_password.origin_verify.result
  logs_bucket_id             = data.terraform_remote_state.logging.outputs.bucket_id
}

module "database" {
  source = "../../../modules/database"

  env                = var.env
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
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
