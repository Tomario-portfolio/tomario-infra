variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "db_name" {
  type    = string
  default = "tomario"
}

variable "db_username" {
  type    = string
  default = "admin"
}

# variable "ecs_sg_id" {（循環依存のため削除。RDS SGへの許可はbackendモジュールで管理）
#   type = string
# }
