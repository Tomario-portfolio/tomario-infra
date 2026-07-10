terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket  = "tomario-tfstate-nonprod"
    key     = "shared/terraform.tfstate"
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

# nonprodアカウント共通のセキュリティ監視。軽量版（Config/SecurityHubは無効、naming_convention.md参照）
module "security" {
  source = "../../../modules/security"

  env                 = var.env
  aws_region          = var.aws_region
  enable_security_hub = false
  enable_config       = false
}

# nonprodアカウント共通のコスト管理
module "cost" {
  source = "../../../modules/cost"

  env         = var.env
  alarm_email = var.alarm_email
}

# nonprodアカウント共通のECR（devからterraform state mvで移行、destroy/createは使わない）
# name="tomario-app"は移行前からの既存リポジトリ名をそのまま維持（ECRはリネーム不可のため）
module "ecr" {
  source = "../../../modules/ecr"

  env  = var.env
  name = "tomario-app"
}
