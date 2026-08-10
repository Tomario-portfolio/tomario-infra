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

variable "daily_budget_usd" {
  description = "日次コスト異常検知の閾値（USD）。cost-stop状態でのベースライン実測を少し上回る値を環境ごとに指定する（nonprod/sharedは約$0.23/日の実測値に基づき0.24をデフォルトのまま使用）"
  type        = number
  default     = 0.24
}
