terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      # WAF(CloudFront)のBlockedRequestsメトリクスはus-east-1にしか存在しないため、
      # ALB/ECS/RDSアラーム用のデフォルトプロバイダ(ap-northeast-1)とは別に必要
      configuration_aliases = [aws.us_east_1]
    }
  }
}
