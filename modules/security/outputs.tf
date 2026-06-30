output "cloudtrail_arn" {
  description = "CloudTrail証跡のARN"
  value       = aws_cloudtrail.main.arn
}
