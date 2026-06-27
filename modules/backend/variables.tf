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

# variable "instance_type" {（旧・EC2用）
#   type    = string
#   default = "t3.micro"
# }
