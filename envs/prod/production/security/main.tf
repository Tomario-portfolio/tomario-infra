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

  # セキュリティスタック（WAF + Config + Security Hub）を一括ON/OFFするフラグ。
  # 値は security-stack.yml（workflow_dispatch）が SECURITY_STACK_ENABLED 変数経由で制御する。
  # 常時起動コストに見合わないため、必要な期間だけ有効化する運用（security-environment-design.md、2026-08-03決定）。
  # 手順は docs/security-stack-runbook.md
  enable_security_hub = var.enable_security_stack
  enable_config       = var.enable_security_stack

  cloudtrail_bucket_name = data.terraform_remote_state.logging.outputs.bucket_id
}
