variable "env" {
  description = "環境名（dev/staging/production）。ECSクラスター/サービス名を tomario-<env>-* 規則で組み立てる"
  type        = string
}

variable "secret_arn" {
  description = "ローテーション対象のFlask SECRET_KEYのシークレットARN（modules/backendの出力）"
  type        = string
}

variable "rotation_days" {
  description = "ローテーションの間隔（日）。ローテーションのたびにECSタスクが入れ替わるため、頻度は控えめにする"
  type        = number
  default     = 90
}
