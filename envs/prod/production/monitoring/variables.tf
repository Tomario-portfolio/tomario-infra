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
