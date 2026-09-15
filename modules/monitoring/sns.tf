resource "aws_sns_topic" "alarm" {
  name = "tomario-${var.env}-alarm"

  tags = {
    Name = "tomario-${var.env}-alarm"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarm.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatchアラームのalarm_actions/ok_actionsは同一リージョンのSNSトピックしか
# 指定できないため、us-east-1で作るWAFアラーム専用に別トピックが必要
resource "aws_sns_topic" "waf_alarm" {
  count    = var.enable_waf_alarm ? 1 : 0
  provider = aws.us_east_1
  name     = "tomario-${var.env}-waf-alarm"

  tags = {
    Name = "tomario-${var.env}-waf-alarm"
  }
}

resource "aws_sns_topic_subscription" "waf_alarm_email" {
  count     = var.enable_waf_alarm ? 1 : 0
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.waf_alarm[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
