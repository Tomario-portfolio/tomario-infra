variable "env" {
  type = string
}

variable "alb_dns_name" {
  type        = string
  description = "ALBのDNS名（FlaskAPIへのオリジン）"
}

variable "origin_verify_header_value" {
  type        = string
  sensitive   = true
  description = "ALBへのオリジンリクエストに付与するシークレットヘッダー値（SEC-7: ALB直アクセス拒否の検証用）"
}
