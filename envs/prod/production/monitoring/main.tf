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
    key          = "production/monitoring/terraform.tfstate"
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

# WAF(CloudFront)のBlockedRequestsメトリクスを見るアラームはus-east-1に作る必要がある
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

data "terraform_remote_state" "database" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-prod"
    key    = "production/database/terraform.tfstate"
    region = "ap-northeast-1"
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

data "terraform_remote_state" "frontend" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-prod"
    key    = "production/frontend/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "monitoring" {
  source = "../../../../modules/monitoring"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  env                          = var.env
  alarm_email                  = var.alarm_email
  alb_arn_suffix               = data.terraform_remote_state.backend.outputs.alb_arn_suffix
  target_group_arn_suffix      = data.terraform_remote_state.backend.outputs.target_group_arn_suffix
  ecs_service_name             = data.terraform_remote_state.backend.outputs.ecs_service_name
  db_instance_identifier       = data.terraform_remote_state.database.outputs.db_instance_identifier
  enable_autoscaling_dashboard = true
  enable_waf_alarm             = var.enable_security_stack
  waf_cloudfront_web_acl_name  = data.terraform_remote_state.frontend.outputs.waf_cloudfront_web_acl_name
}
