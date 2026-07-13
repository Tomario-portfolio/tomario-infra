resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = "${var.logs_bucket_arn}/flow-logs"

  tags = {
    Name = "tomario-${var.env}-flow-log"
  }
}
