resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_host" {
  alarm_name          = "tomario-${var.env}-alb-unhealthy-host"
  alarm_description   = "ALBの非ヘルシーホスト数が1以上になっています"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]

  tags = {
    Name = "tomario-${var.env}-alb-unhealthy-host"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "tomario-${var.env}-ecs-cpu"
  alarm_description   = "ECSサービスのCPU使用率が80%以上になっています"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = "tomario-${var.env}-cluster"
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]

  tags = {
    Name = "tomario-${var.env}-ecs-cpu"
  }
}

# resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {（旧）
#   alarm_name  = "tomario-${var.env}-ec2-cpu"
#   namespace   = "AWS/EC2"
#   dimensions = {
#     AutoScalingGroupName = var.asg_name
#   }
# }

resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  count = var.enable_waf_alarm ? 1 : 0
  # WAF(CloudFront)のBlockedRequestsメトリクスはus-east-1にしか存在しないため、
  # CloudWatchアラームも同じリージョンに作る必要がある（他のアラームはap-northeast-1のまま）
  provider            = aws.us_east_1
  alarm_name          = "tomario-${var.env}-waf-blocked"
  alarm_description   = "WAF(CloudFront)のBlockedRequestsが閾値を超えています"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  # CLOUDFRONTスコープのWebACLはRegionディメンションを持たない（REGIONALスコープ用の
  # 手順書サンプルコマンドをそのまま踏襲したことによる誤り。実機でlist-metricsを確認して判明）
  dimensions = {
    WebACL = var.waf_cloudfront_web_acl_name
    Rule   = "ALL"
  }

  # alarm_actionsは同一リージョン(us-east-1)のSNSトピックである必要がある
  alarm_actions = [aws_sns_topic.waf_alarm[0].arn]
  ok_actions    = [aws_sns_topic.waf_alarm[0].arn]

  tags = {
    Name = "tomario-${var.env}-waf-blocked"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "tomario-${var.env}-rds-cpu"
  alarm_description   = "RDSのCPU使用率が80%以上になっています"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]

  tags = {
    Name = "tomario-${var.env}-rds-cpu"
  }
}
