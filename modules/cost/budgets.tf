resource "aws_budgets_budget" "monthly" {
  name         = "tomario-${var.env}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alarm_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alarm_email]
  }
}

# 日次コスト異常検知：「いつも通り」の日は通知せず、想定外にコストが増えた日だけ気づけるよう、
# 環境ごとのベースライン実測に基づく閾値をvar.daily_budget_usdで渡す（envごとに構成が違うため共通化しない）
resource "aws_budgets_budget" "daily_report" {
  name         = "tomario-${var.env}-daily-cost-report"
  budget_type  = "COST"
  limit_amount = var.daily_budget_usd
  limit_unit   = "USD"
  time_unit    = "DAILY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alarm_email]
  }
}
