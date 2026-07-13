variable "env" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "logs_bucket_arn" {
  type        = string
  description = "VPC Flow Logsの出力先S3バケットARN（modules/loggingの出力）"
}
