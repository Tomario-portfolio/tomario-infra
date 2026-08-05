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

# state分割（コンポーネント単位）により、logging/network/database/backend/frontend/monitoringは
# それぞれ envs/nonprod/dev/{component}/ に独立している（各コンポーネント側のmain.tf参照）。
# このroot stateは現時点で管理対象リソースを持たない。
