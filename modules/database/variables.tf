variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ec2_sg_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "tomario"
}

variable "db_username" {
  type    = string
  default = "admin"
}
