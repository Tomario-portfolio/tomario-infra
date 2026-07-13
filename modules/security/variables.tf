variable "env" {
  description = "環境名（dev / prd）"
  type        = string
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
}

variable "enable_security_hub" {
  description = "Security Hub + CIS準拠チェックを有効化するか（AWS Config必須・課金あり）"
  type        = bool
  default     = false
}

variable "enable_config" {
  description = "AWS Configを有効化するか（Security Hub CISチェックの前提条件・課金あり）"
  type        = bool
  default     = false
}

variable "cloudtrail_bucket_name" {
  description = "CloudTrailの出力先S3バケット名（modules/loggingの出力）"
  type        = string
}
