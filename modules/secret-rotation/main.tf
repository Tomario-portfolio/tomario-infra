# Flask SECRET_KEYの自動ローテーション（SEC-8）
# Secrets Managerが一定間隔でローテーションLambdaを呼び、新しい鍵への切り替えとECSタスクの入れ替えを行う。
# ECSサービスはcost-stopで削除されるため、クラスター/サービス名はモジュールの出力ではなく命名規則で組み立てる

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  ecs_cluster = "tomario-${var.env}-cluster"
  ecs_service = "tomario-${var.env}-service"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../../lambda/flask-secret-rotation/handler.py"
  output_path = "${path.module}/../../lambda/flask-secret-rotation/handler.zip"
}

resource "aws_iam_role" "this" {
  name = "tomario-${var.env}-flask-secret-rotation-lambda"

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
    Name = "tomario-${var.env}-flask-secret-rotation-lambda"
  }
}

resource "aws_iam_role_policy" "this" {
  name = "tomario-${var.env}-flask-secret-rotation-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RotateFlaskSecretKey"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage",
        ]
        Resource = var.secret_arn
      },
      {
        # GetRandomPasswordは特定のリソースを対象としないAPIのため、Resourceを絞れない
        Sid      = "GenerateRandomKey"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetRandomPassword"]
        Resource = "*"
      },
      {
        Sid    = "RedeployEcsService"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
        ]
        Resource = "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:service/${local.ecs_cluster}/${local.ecs_service}"
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/tomario-${var.env}-flask-secret-rotation"
  retention_in_days = 30

  tags = {
    Name = "tomario-${var.env}-flask-secret-rotation-logs"
  }
}

resource "aws_lambda_function" "this" {
  function_name    = "tomario-${var.env}-flask-secret-rotation"
  role             = aws_iam_role.this.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      ECS_CLUSTER = local.ecs_cluster
      ECS_SERVICE = local.ecs_service
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = {
    Name = "tomario-${var.env}-flask-secret-rotation"
  }
}

resource "aws_lambda_permission" "secretsmanager" {
  statement_id   = "AllowSecretsManagerInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.this.function_name
  principal      = "secretsmanager.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# 作成時に1回目のローテーションが即時実行される（rotate_immediatelyのデフォルトはtrue）。
# これによりAWSPREVIOUS（1つ前の鍵）が作られ、アプリ側で旧鍵のcookieも受け付ける対応（SECRET_KEY_FALLBACKS）の前提が整う
resource "aws_secretsmanager_secret_rotation" "this" {
  secret_id           = var.secret_arn
  rotation_lambda_arn = aws_lambda_function.this.arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }

  depends_on = [aws_lambda_permission.secretsmanager]
}
