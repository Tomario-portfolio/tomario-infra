output "cloudfront_domain_name" {
  value = module.frontend.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  value = module.frontend.cloudfront_distribution_id
}

output "s3_bucket_name" {
  value = module.frontend.s3_bucket_name
}

output "waf_cloudfront_web_acl_name" {
  value = var.enable_security_stack ? module.waf_cloudfront[0].web_acl_name : null
}
