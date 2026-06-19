variable "env" {
  type = string
}

variable "alb_dns_name" {
  type        = string
  description = "ALBのDNS名（FlaskAPIへのオリジン）"
}
