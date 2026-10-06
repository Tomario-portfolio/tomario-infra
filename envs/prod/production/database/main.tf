terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket       = "tomario-tfstate-prod"
    key          = "production/database/terraform.tfstate"
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

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-prod"
    key    = "production/network/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "database" {
  source = "../../../../modules/database"

  env                = var.env
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  # ストレージ枯渇で書き込めなくなるのを防ぐため、productionのみ100GBまで自動拡張する
  # （課金は実際に拡張された容量分のみ）
  max_allocated_storage = 100

  # multi_az/instance_classはデフォルト値のまま（Multi-AZ無効・db.t3.micro）。
  # Multi-AZは検討中のためオフだが、変数化済みなので必要な時にtrueへ変更してapplyするだけで有効化できる
}

# RDSの7日強制起動制約対策（REL-4/COST-4/SUS-3）
module "rds_autostop" {
  source = "../../../../modules/rds-autostop"

  env = var.env
}
