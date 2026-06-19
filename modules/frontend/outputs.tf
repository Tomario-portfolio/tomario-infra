output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.this.domain_name
  description = "CloudFrontのドメイン名（アクセスURL）"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.this.id
  description = "CloudFrontディストリビューションID（キャッシュ無効化に使用）"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.frontend.bucket
  description = "フロントエンドS3バケット名"
}
