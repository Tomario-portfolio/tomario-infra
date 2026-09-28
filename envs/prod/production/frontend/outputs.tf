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
  # enable_security_stack=falseの時にnullを返すと、Terraformがstateからこの出力キーごと
  # 落としてしまい、参照側（monitoring）が"Unsupported attribute"で落ちる（try()でも防げない、
  # 属性が型として存在しないという設定検証段階のエラーのため）。空文字列なら実値として保存され、
  # キー自体は必ず存在する。参照側はenable_waf_alarm=falseでcount=0になり実際には使われない
  value = var.enable_security_stack ? module.waf_cloudfront[0].web_acl_name : ""
}
