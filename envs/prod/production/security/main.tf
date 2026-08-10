terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "tomario-tfstate-prod"
    key          = "production/security/terraform.tfstate"
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

data "terraform_remote_state" "logging" {
  backend = "s3"
  config = {
    bucket = "tomario-tfstate-prod"
    key    = "production/logging/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "security" {
  source = "../../../../modules/security"

  env        = var.env
  aws_region = var.aws_region

  # 面接期間のみtrue、それ以外はfalse（security-environment-design.md、2026-08-03決定）。
  # 常時起動コスト（~$3〜5/月）に見合わないため、必要な時だけ手動でtrueに切り替える運用
  enable_security_hub = false
  enable_config       = false

  cloudtrail_bucket_name = data.terraform_remote_state.logging.outputs.bucket_id
}
