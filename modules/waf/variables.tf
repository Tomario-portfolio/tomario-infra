variable "env" {
  description = "環境名（production / staging など）"
  type        = string
}

variable "scope" {
  description = "WAFv2のスコープ。CLOUDFRONT（CloudFront用・プロバイダはus-east-1必須）または REGIONAL（ALB用）"
  type        = string

  validation {
    condition     = contains(["CLOUDFRONT", "REGIONAL"], var.scope)
    error_message = "scope は CLOUDFRONT か REGIONAL のいずれかを指定する。"
  }
}

variable "name_suffix" {
  description = "Web ACL名の末尾（cloudfront / alb）。スコープ違いのWeb ACLを名前で区別するため"
  type        = string
}

variable "rate_limit" {
  description = "レートベースルールのしきい値（5分あたり・同一IPのリクエスト数）。超過分をブロックする"
  type        = number
  default     = 2000
}

variable "enable_logging" {
  description = "CloudWatch LogsへWAFログ（ブロック/カウントしたリクエスト）を出力するか"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "WAFログのCloudWatch Logs保持日数"
  type        = number
  default     = 30
}
