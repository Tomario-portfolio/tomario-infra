variable "env" {
  description = "環境名"
  type        = string
}

variable "alarm_email" {
  description = "アラーム通知先メールアドレス"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALBのARNサフィックス（CloudWatchアラームのディメンション用）"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ターゲットグループのARNサフィックス（CloudWatchアラームのディメンション用）"
  type        = string
}

variable "ecs_service_name" {
  description = "ECSサービス名（CloudWatchアラームのディメンション用）"
  type        = string
}

variable "db_instance_identifier" {
  description = "RDSインスタンス識別子（CloudWatchアラームのディメンション用）"
  type        = string
}

# variable "asg_name" {（旧・EC2用）
#   description = "Auto ScalingグループのASG名（CloudWatchアラームのディメンション用）"
#   type        = string
# }
