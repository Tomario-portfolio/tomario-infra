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

variable "bootstrap_image" {
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:latest"
  description = "Terraformが初回にタスク定義を作成する際にのみ使う仮イメージ。ECRのイメージタグ運用（SHAタグのみ、:latestなし）に依存させないための踏み台で、実イメージはtomario-app側のCI/CDがデプロイ時に上書きする（aws_ecs_serviceのignore_changesで以降は管理対象外）"
}

# variable "instance_type" {（旧・EC2用）
#   type    = string
#   default = "t3.micro"
# }
