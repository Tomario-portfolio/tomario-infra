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

variable "enable_security_stack" {
  description = "セキュリティスタック有効時、ALB用WAF Web ACLを作成しALBにアタッチする。security-stack.yml が SECURITY_STACK_ENABLED 変数経由で制御。適用は prod 起動中が前提。手順は docs/security-stack-runbook.md"
  type        = bool
  default     = false
}
