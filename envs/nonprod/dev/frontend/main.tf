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
    key          = "dev/frontend/terraform.tfstate"
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

data "terraform_remote_state" "backend" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-nonprod"
    key    = "dev/backend/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "frontend" {
  source = "../../../../modules/frontend"

  env                        = var.env
  alb_dns_name               = data.terraform_remote_state.backend.outputs.alb_dns_name
  origin_verify_header_value = data.terraform_remote_state.backend.outputs.origin_verify_header_value
}
