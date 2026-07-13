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
