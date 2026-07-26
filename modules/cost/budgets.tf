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

# 日次コスト異常検知：cost-stop状態でのベースライン実測（約$0.23/日、2026-07-26 Cost Explorerで確認）を
# わずかに上回る$0.24を閾値にすることで、「いつも通り」の日は通知せず、想定外にコストが増えた日だけ気づける
resource "aws_budgets_budget" "daily_report" {
  name         = "tomario-${var.env}-daily-cost-report"
  budget_type  = "COST"
  limit_amount = "0.24"
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
