terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "tomario-tfstate-nonprod"
    key          = "staging/monitoring/terraform.tfstate"
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

data "terraform_remote_state" "database" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-nonprod"
    key    = "staging/database/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

data "terraform_remote_state" "backend" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-nonprod"
    key    = "staging/backend/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "monitoring" {
  source = "../../../../modules/monitoring"

  env                          = var.env
  alarm_email                  = var.alarm_email
  alb_arn_suffix               = data.terraform_remote_state.backend.outputs.alb_arn_suffix
  target_group_arn_suffix      = data.terraform_remote_state.backend.outputs.target_group_arn_suffix
  ecs_service_name             = data.terraform_remote_state.backend.outputs.ecs_service_name
  db_instance_identifier       = data.terraform_remote_state.database.outputs.db_instance_identifier
  enable_autoscaling_dashboard = true
}
