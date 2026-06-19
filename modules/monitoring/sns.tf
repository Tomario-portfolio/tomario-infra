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
