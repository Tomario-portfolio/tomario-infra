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
    key          = "production/frontend/terraform.tfstate"
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

# CloudFront用WAF Web ACL（CLOUDFRONTスコープ）はus-east-1に作成する必要がある
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "tomario"
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }
}

data "terraform_remote_state" "backend" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-prod"
    key    = "production/backend/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

# CloudFront用WAF（CLOUDFRONTスコープ）。セキュリティスタック有効時のみ作成（SEC-5、security-stack-runbook.md）
module "waf_cloudfront" {
  count  = var.enable_security_stack ? 1 : 0
  source = "../../../../modules/waf"

  providers = {
    aws = aws.us_east_1
  }

  env         = var.env
  scope       = "CLOUDFRONT"
  name_suffix = "cloudfront"
}

module "frontend" {
  source = "../../../../modules/frontend"

  env                        = var.env
  alb_dns_name               = data.terraform_remote_state.backend.outputs.alb_dns_name
  origin_verify_header_value = data.terraform_remote_state.backend.outputs.origin_verify_header_value
  web_acl_arn                = var.enable_security_stack ? module.waf_cloudfront[0].web_acl_arn : null
}
