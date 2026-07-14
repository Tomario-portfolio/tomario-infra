# Task Execution Role：ECSサービスがコンテナ起動に使う
data "aws_iam_policy_document" "task_exec_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_exec" {
  name               = "tomario-${var.env}-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.task_exec_assume_role.json

  tags = {
    Name = "tomario-${var.env}-task-exec-role"
  }
}

# ECRイメージ取得・CloudWatch Logsへの書き込みを許可するAWS管理ポリシー
resource "aws_iam_role_policy_attachment" "task_exec" {
  role       = aws_iam_role.task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets ManagerからDB接続情報を取得する権限
data "aws_iam_policy_document" "task_exec_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.db_secret_arn,
      aws_secretsmanager_secret.flask_secret_key.arn
    ]
  }
}

resource "aws_iam_role_policy" "task_exec_secrets" {
  name   = "tomario-${var.env}-task-exec-secrets"
  role   = aws_iam_role.task_exec.id
  policy = data.aws_iam_policy_document.task_exec_secrets.json
}

# Task Role：コンテナ（アプリ）が使う。現時点では最小権限
data "aws_iam_policy_document" "task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "tomario-${var.env}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role.json

  tags = {
    Name = "tomario-${var.env}-task-role"
  }
}

# ECS Exec（aws ecs execute-command）で使うSSMチャネル権限
# デフォルトでは無効（enable_execute_commandをCLIで一時的に有効化した時のみ使われる）
data "aws_iam_policy_document" "task_exec_command" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_exec_command" {
  name   = "tomario-${var.env}-task-exec-command"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_exec_command.json
}

# data "aws_iam_policy_document" "ec2_assume_role" {（旧）
#   statement {
#     actions = ["sts:AssumeRole"]
#     principals {
#       type        = "Service"
#       identifiers = ["ec2.amazonaws.com"]
#     }
#   }
# }
#
# resource "aws_iam_role" "ec2" {
#   name               = "tomario-${var.env}-ec2-role"
#   assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
# }
#
# resource "aws_iam_role_policy_attachment" "ssm" {
#   role       = aws_iam_role.ec2.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }
#
# resource "aws_iam_role_policy" "ec2_app" { ... }
# resource "aws_iam_instance_profile" "ec2" { ... }
