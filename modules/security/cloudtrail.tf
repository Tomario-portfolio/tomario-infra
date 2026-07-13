data "aws_caller_identity" "current" {}

resource "aws_cloudtrail" "main" {
  name                          = "tomario-${var.env}-trail"
  s3_bucket_name                = var.cloudtrail_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  tags = {
    Name = "tomario-${var.env}-trail"
  }
}
