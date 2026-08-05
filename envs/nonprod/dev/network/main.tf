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
    key          = "dev/network/terraform.tfstate"
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
    bucket = "tomario-tfstate-nonprod"
    key    = "dev/logging/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "network" {
  source = "../../../../modules/network"

  env                  = var.env
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  logs_bucket_arn      = data.terraform_remote_state.logging.outputs.bucket_arn
}
