resource "aws_guardduty_detector" "main" {
  enable = true

  tags = {
    Name = "tomario-${var.env}-guardduty"
  }
}
