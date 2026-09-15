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

variable "alarm_email" {
  description = "アラーム通知先メールアドレス"
  type        = string
}

variable "enable_security_stack" {
  description = "セキュリティスタック有効時、WAF(CloudFront)のBlockedRequestsアラームを作成する。security-stack.yml が SECURITY_STACK_ENABLED 変数経由で制御。"
  type        = bool
  default     = false
}
