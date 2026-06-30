resource "aws_ce_anomaly_monitor" "main" {
  name         = "tomario-${var.env}-anomaly-monitor"
  monitor_type = "DIMENSIONAL"

  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "main" {
  name      = "tomario-${var.env}-anomaly-subscription"
  frequency = "IMMEDIATE"

  monitor_arn_list = [aws_ce_anomaly_monitor.main.arn]

  subscriber {
    type    = "EMAIL"
    address = var.alarm_email
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = ["5"]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }
}
