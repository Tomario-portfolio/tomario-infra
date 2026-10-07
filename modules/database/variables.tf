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

variable "multi_az" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type        = bool
  default     = true
  description = "destroy時に最終スナップショットを残さない場合はtrue。実データを持つ環境ではfalseにする"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

# variable "ecs_sg_id" {（循環依存のため削除。RDS SGへの許可はbackendモジュールで管理）
#   type = string
# }

variable "max_allocated_storage" {
  type        = number
  default     = 0
  description = "ストレージ自動拡張の上限（GB）。0は自動拡張なし（allocated_storageの20GB固定）"
}
