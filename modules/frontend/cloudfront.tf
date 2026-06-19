locals {
  s3_origin_id  = "tomario-${var.env}-s3-origin"
  alb_origin_id = "tomario-${var.env}-alb-origin"

  # AWS管理キャッシュポリシーID
  cache_policy_optimized = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
  cache_policy_disabled  = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled

  # AWS管理オリジンリクエストポリシーID
  origin_request_policy_alb = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "tomario-${var.env}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_All"

  # S3オリジン（静的ファイル）
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # ALBオリジン（Flask API）
  origin {
    domain_name = var.alb_dns_name
    origin_id   = local.alb_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # デフォルトキャッシュビヘイビア（静的ファイル → S3）
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    cache_policy_id        = local.cache_policy_optimized
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # /api/* → ALB（キャッシュ無効）
  ordered_cache_behavior {
    path_pattern             = "/api/*"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = local.alb_origin_id
    cache_policy_id          = local.cache_policy_disabled
    origin_request_policy_id = local.origin_request_policy_alb
    viewer_protocol_policy   = "redirect-to-https"
    compress                 = true
  }

  # SPAのルーティング対応（404 → index.html）
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  # CloudFrontデフォルト証明書（独自ドメインなし）
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "tomario-${var.env}-cf"
  }
}
