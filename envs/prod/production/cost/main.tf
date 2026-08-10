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
    key          = "production/cost/terraform.tfstate"
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

module "cost" {
  source = "../../../../modules/cost"

  env                = var.env
  alarm_email        = var.alarm_email
  monthly_budget_usd = 130

  # daily_budget_usdはデフォルト(0.24)のまま使用。nonprodと同じ理由（cost-stop状態のベースライン実測に基づく閾値）
  # だが、これはnonprodの実測値を暫定的に流用しているだけで、production自体の実測値ではない。
  # wave5（backend）まで構築が進みcost-stop状態の実コストが測定できた時点で、production固有の値に見直すこと
}
