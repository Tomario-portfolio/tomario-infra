variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "tfstate_bucket_name" {
  description = "tfstate保管用S3バケット名（グローバル一意。例: tomario-tfstate-prod）"
  type        = string
}

variable "github_repo" {
  description = "インフラCIリポジトリ（例: Tomario-portfolio/tomario-infra）"
  type        = string
}

variable "github_app_repo" {
  description = "アプリデプロイリポジトリ（例: Tomario-portfolio/tomario-app）"
  type        = string
}

variable "github_environment" {
  description = "信頼条件を絞るGitHub Environment名（Required reviewers等の保護ルールを設定する想定）"
  type        = string
  default     = "prod"
}
