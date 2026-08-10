terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket       = "tomario-tfstate-prod"
    key          = "production/backend/terraform.tfstate"
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

# CloudFront経由のリクエストであることをALBが検証するためのシークレットヘッダー値（SEC-7、dev/stagingと同じ）
resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

# Flask SECRET_KEY。modules/backendのデフォルト値("dev-secret-key-change-in-prod")は
# プレースホルダーのためproductionでは使わず、ランダム値を生成して渡す
# （aws_secretsmanager_secret_versionはignore_changes = [secret_string]のため初回apply時の値が
# そのまま使われ続ける。事後のローテーションはAWS側で別途行う運用）
resource "random_password" "flask_secret_key" {
  length  = 50
  special = true
}

data "terraform_remote_state" "logging" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-prod"
    key    = "production/logging/terraform.tfstate"
    region = "ap-northeast-1"
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

data "terraform_remote_state" "database" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-prod"
    key    = "production/database/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "backend" {
  source = "../../../../modules/backend"

  env                        = var.env
  vpc_id                     = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids          = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_ids         = data.terraform_remote_state.network.outputs.private_subnet_ids
  db_host                    = data.terraform_remote_state.database.outputs.rds_address
  db_secret_arn              = data.terraform_remote_state.database.outputs.master_user_secret_arn
  rds_sg_id                  = data.terraform_remote_state.database.outputs.rds_sg_id
  logs_bucket_id             = data.terraform_remote_state.logging.outputs.bucket_id
  origin_verify_header_value = random_password.origin_verify.result
  secret_key                 = random_password.flask_secret_key.result
  log_retention_days         = 90

  # production用ECR（wave2）のbootstrapタグを明示的に指定。デフォルトはnonprodアカウントのECR URL固定のため
  bootstrap_image = "236782813946.dkr.ecr.ap-northeast-1.amazonaws.com/tomario-production-app:bootstrap"

  # desired_count/autoscalingはstagingで検証済みの値をそのまま引き継ぐ（新規に試すものではない）
  desired_count            = 2
  autoscaling_enabled      = true
  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 4
  autoscaling_target_cpu   = 70
}
