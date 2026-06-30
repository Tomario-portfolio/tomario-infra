variable "env" {
  description = "環境名"
  type        = string
}

variable "alarm_email" {
  description = "コストアラート通知先メールアドレス"
  type        = string
}

variable "monthly_budget_usd" {
  description = "月間予算上限（USD）"
  type        = number
  default     = 10
}
