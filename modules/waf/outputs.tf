output "web_acl_arn" {
  description = "Web ACLのARN（CloudFrontのweb_acl_id・ALBのassociationに渡す）"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  description = "Web ACLのID"
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_name" {
  description = "Web ACL名"
  value       = aws_wafv2_web_acl.this.name
}
