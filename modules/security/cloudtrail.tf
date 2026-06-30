resource "aws_cloudtrail" "main" {
  name                          = "tomario-${var.env}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  tags = {
    Name = "tomario-${var.env}-trail"
  }
}
