resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/vpc/tomario-${var.env}-flow-logs"
  retention_in_days = 7

  tags = {
    Name = "tomario-${var.env}-vpc-flow-logs"
  }
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn

  tags = {
    Name = "tomario-${var.env}-flow-log"
  }
}

resource "aws_iam_role" "flow_log" {
  name               = "tomario-${var.env}-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume.json
}

data "aws_iam_policy_document" "flow_log_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "flow_log" {
  name   = "tomario-${var.env}-flow-log-policy"
  role   = aws_iam_role.flow_log.id
  policy = data.aws_iam_policy_document.flow_log.json
}

data "aws_iam_policy_document" "flow_log" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}
