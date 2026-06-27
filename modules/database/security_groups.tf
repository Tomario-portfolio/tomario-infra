resource "aws_security_group" "rds" {
  name   = "tomario-${var.env}-rds-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tomario-${var.env}-rds-sg"
  }
}

# ECSタスクからの接続許可はbackendモジュールのaws_security_group_ruleで管理する
# （backendとdatabaseの循環依存を防ぐため）
