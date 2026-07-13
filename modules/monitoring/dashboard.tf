resource "aws_cloudwatch_dashboard" "autoscaling" {
  count = var.enable_autoscaling_dashboard ? 1 : 0

  dashboard_name = "tomario-${var.env}-autoscaling"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "RunningTaskCount", "ClusterName", "tomario-${var.env}-cluster", "ServiceName", var.ecs_service_name]
          ]
          period = 60
          stat   = "Average"
          region = "ap-northeast-1"
          title  = "ECS Running Task Count（Application Auto Scalingの挙動可視化）"
        }
      }
    ]
  })
}
