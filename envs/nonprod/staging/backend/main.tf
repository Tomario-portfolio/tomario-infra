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
    bucket       = "tomario-tfstate-nonprod"
    key          = "staging/backend/terraform.tfstate"
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

# CloudFront経由のリクエストであることをALBが検証するためのシークレットヘッダー値（SEC-7、devと同じ）
# frontendとbackend両方が使う値だが、backend（ALBのリスナールール）を主とし、frontend側はこのコンポーネントのoutputを参照する
resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

# Flask SECRET_KEY（セッションcookieの署名鍵）。productionと同様にランダム値を生成して渡す
# （aws_secretsmanager_secret_versionはignore_changes = [secret_string]のため、既存の値を入れ替えるには
# terraform apply -replace=module.backend.aws_secretsmanager_secret_version.flask_secret_key を一度実行する）
resource "random_password" "flask_secret_key" {
  length  = 50
  special = true
}

data "terraform_remote_state" "logging" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-nonprod"
    key    = "staging/logging/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "tomario-tfstate-nonprod"
    key    = "staging/network/terraform.tfstate"
    region = "ap-northeast-1"
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

module "backend" {
  source = "../../../../modules/backend"

  env                        = var.env
  vpc_id                     = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids          = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_ids         = data.terraform_remote_state.network.outputs.private_subnet_ids
  db_host                    = data.terraform_remote_state.database.outputs.rds_address
  db_secret_arn              = data.terraform_remote_state.database.outputs.master_user_secret_arn
  rds_sg_id                  = data.terraform_remote_state.database.outputs.rds_sg_id
  origin_verify_header_value = random_password.origin_verify.result
  logs_bucket_id             = data.terraform_remote_state.logging.outputs.bucket_id
  secret_key                 = random_password.flask_secret_key.result
  log_retention_days         = 30
  desired_count              = 2
  autoscaling_enabled        = true
  autoscaling_min_capacity   = 2
  autoscaling_max_capacity   = 4
  autoscaling_target_cpu     = 70
}
