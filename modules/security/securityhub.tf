resource "aws_securityhub_account" "main" {
  count      = var.enable_security_hub ? 1 : 0
  depends_on = [aws_guardduty_detector.main]
}

resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.main]
}
