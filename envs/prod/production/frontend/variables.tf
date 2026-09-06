variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "env" {
  description = "環境名"
  type        = string
  default     = "production"
}

variable "enable_waf" {
  description = "CloudFront用WAF Web ACLを作成しディストリビューションにアタッチするか。面接期間のみtrue（security-stack-runbook.md）"
  type        = bool
  default     = false
}
