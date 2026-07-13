variable "env" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "bucket_name" {
  type        = string
  default     = null
  description = "バケット名を明示的に指定する場合に使う。指定しない場合はtomario-(env)-logs-(account_id)形式の名前を自動生成する（既存バケットを引き継ぐ場合など、名前を固定したい時に使用）"
}
