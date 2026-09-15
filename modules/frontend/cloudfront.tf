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

# SPAのクライアントサイドルーティング対応。custom_error_response(403→200)による
# エラーコード変換だと、WAFがブロックして生成した403も巻き込んで200にすり替えてしまうため、
# リクエスト時点でのURI書き換えに変更した（拡張子の無いパス=SPAのルートとみなしindex.htmlへ）
resource "aws_cloudfront_function" "spa_routing" {
  name    = "tomario-${var.env}-spa-routing"
  runtime = "cloudfront-js-2.0"
  comment = "拡張子の無いパス（SPAのクライアントサイドルート）をindex.htmlへ書き換える"
  publish = true
  code    = file("${path.module}/functions/spa-routing.js")
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_All"

  # WAF Web ACL（CLOUDFRONTスコープ）。var.web_acl_arnがnullならWAFなし（SEC-5）
  web_acl_id = var.web_acl_arn

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

    # ALBが直アクセスを拒否できるよう、CloudFront経由であることを示すシークレットヘッダーを付与する（SEC-7）
    custom_header {
      name  = "X-Origin-Verify"
      value = var.origin_verify_header_value
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

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_routing.arn
    }
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

  # 404はCloudFront Function(spa_routing)で基本的に発生しなくなるが、想定外のケースの
  # セーフティネットとして残す。403は残さない（WAFブロックの403まで200にすり替わってしまうため）
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
