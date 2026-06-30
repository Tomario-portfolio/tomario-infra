output "budget_name" {
  description = "AWS Budgets名"
  value       = aws_budgets_budget.monthly.name
}

output "anomaly_monitor_arn" {
  description = "Cost Anomaly MonitorのARN"
  value       = aws_ce_anomaly_monitor.main.arn
}
