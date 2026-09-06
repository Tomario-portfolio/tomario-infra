# WAFログの出力先。ロググループ名は "aws-waf-logs-" で始まる必要がある（WAFv2の制約）
resource "aws_cloudwatch_log_group" "waf" {
  count             = var.enable_logging ? 1 : 0
  name              = "aws-waf-logs-tomario-${var.env}-${var.name_suffix}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "aws-waf-logs-tomario-${var.env}-${var.name_suffix}"
  }
}

# CLI/API経由でWAFログをCloudWatch Logsへ配信するには、ロググループ側に
# vended log delivery（delivery.logs.amazonaws.com）への書き込み許可が必要
data "aws_iam_policy_document" "waf_log_delivery" {
  count = var.enable_logging ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    resources = ["${aws_cloudwatch_log_group.waf[0].arn}:*"]
  }
}

resource "aws_cloudwatch_log_resource_policy" "waf" {
  count           = var.enable_logging ? 1 : 0
  policy_name     = "tomario-${var.env}-${var.name_suffix}-waf-logs"
  policy_document = data.aws_iam_policy_document.waf_log_delivery[0].json
}

resource "aws_wafv2_web_acl_logging_configuration" "waf" {
  count                   = var.enable_logging ? 1 : 0
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
  resource_arn            = aws_wafv2_web_acl.this.arn

  depends_on = [aws_cloudwatch_log_resource_policy.waf]
}
