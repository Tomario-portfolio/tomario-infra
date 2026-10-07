data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../../lambda/rds-autostop/handler.py"
  output_path = "${path.module}/../../lambda/rds-autostop/handler.zip"
}

resource "aws_iam_role" "this" {
  name = "tomario-${var.env}-rds-autostop-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "tomario-${var.env}-rds-autostop-lambda"
  }
}

resource "aws_iam_role_policy" "this" {
  name = "tomario-${var.env}-rds-autostop-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RdsCheckAndStop"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeEvents",
          "rds:StopDBInstance",
        ]
        Resource = "*"
      },
      {
        Sid    = "EcsCheck"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
        ]
        Resource = "*"
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/tomario-${var.env}-rds-autostop"
  retention_in_days = 7

  tags = {
    Name = "tomario-${var.env}-rds-autostop-logs"
  }
}

resource "aws_lambda_function" "this" {
  function_name    = "tomario-${var.env}-rds-autostop"
  role             = aws_iam_role.this.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      RDS_IDENTIFIER = "tomario-${var.env}-rds"
      ECS_CLUSTER    = "tomario-${var.env}-cluster"
      ECS_SERVICE    = "tomario-${var.env}-service"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = {
    Name = "tomario-${var.env}-rds-autostop"
  }
}

resource "aws_cloudwatch_event_rule" "daily" {
  name        = "tomario-${var.env}-rds-autostop-schedule"
  description = "RDSの7日強制起動制約対策：1時間ごとにチェックし、7日制約で自動起動されECS非稼働なら再stopする（REL-4/COST-4/SUS-3）"
  # 1日1回（JST 05:00）だと、実行直後に自動起動された場合に最大約24時間RDSが稼働し続けたため（2026-10-06に発生）、
  # 1時間ごとに変更。cost-start中の誤停止は、Lambda側で自動起動のRDSイベントを条件にすることで防ぐ
  schedule_expression = "rate(1 hour)"

  tags = {
    Name = "tomario-${var.env}-rds-autostop-schedule"
  }
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.daily.name
  arn  = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}
