# RDS SGへのインバウンドルール（循環依存を避けるためbackendモジュールで管理）
resource "aws_security_group_rule" "ecs_to_rds" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = var.rds_sg_id
  source_security_group_id = aws_security_group.ecs.id
}

resource "aws_ecr_repository" "this" {
  name                 = "tomario-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "tomario-app"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "最新5世代のみ保持"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_secretsmanager_secret" "flask_secret_key" {
  name = "tomario-${var.env}-flask-secret-key"

  tags = {
    Name = "tomario-${var.env}-flask-secret-key"
  }
}

resource "aws_secretsmanager_secret_version" "flask_secret_key" {
  secret_id     = aws_secretsmanager_secret.flask_secret_key.id
  secret_string = var.secret_key

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/tomario-${var.env}"
  retention_in_days = 7

  tags = {
    Name = "tomario-${var.env}-ecs-logs"
  }
}

resource "aws_ecs_cluster" "this" {
  name = "tomario-${var.env}-cluster"

  tags = {
    Name = "tomario-${var.env}-cluster"
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = "tomario-${var.env}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_exec.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "tomario-app"
      image     = "${aws_ecr_repository.this.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      # DBホスト・ポート・DB名は固定値として環境変数で渡す
      environment = [
        { name = "DB_HOST", value = var.db_host },
        { name = "DB_PORT", value = "3306" },
        { name = "DB_NAME", value = "tomario" }
      ]

      # 機密情報はSecrets Managerから取得して注入する
      secrets = [
        { name = "DB_USER", valueFrom = "${var.db_secret_arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" },
        { name = "SECRET_KEY", valueFrom = aws_secretsmanager_secret.flask_secret_key.arn }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "this" {
  name            = "tomario-${var.env}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "tomario-app"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]

  # cost-stop/startでCLIからタスク数を操作するためTerraformの管理対象外にする
  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }
}
