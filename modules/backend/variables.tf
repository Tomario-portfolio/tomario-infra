variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "db_host" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "rds_sg_id" {
  type = string
}

variable "secret_key" {
  type    = string
  default = "dev-secret-key-change-in-prod"
}

variable "origin_verify_header_value" {
  type        = string
  sensitive   = true
  description = "CloudFrontがオリジンリクエストに付与するシークレットヘッダー値（SEC-7: ALB直アクセス拒否の検証用）"
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "autoscaling_enabled" {
  type    = bool
  default = false
}

variable "autoscaling_min_capacity" {
  type    = number
  default = 1
}

variable "autoscaling_max_capacity" {
  type    = number
  default = 1
}

variable "autoscaling_target_cpu" {
  type    = number
  default = 70
}

variable "bootstrap_image" {
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:latest"
  description = "Terraformが初回にタスク定義を作成する際にのみ使う仮イメージ。ECRのイメージタグ運用（SHAタグのみ、:latestなし）に依存させないための踏み台で、実イメージはtomario-app側のCI/CDがデプロイ時に上書きする（aws_ecs_serviceのignore_changesで以降は管理対象外）"
}

# variable "instance_type" {（旧・EC2用）
#   type    = string
#   default = "t3.micro"
# }
