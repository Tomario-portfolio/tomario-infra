resource "aws_security_group" "rds" {
  name   = "tomario-${var.env}-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ec2_sg_id]
  }

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

resource "aws_db_subnet_group" "this" {
  name       = "tomario-${var.env}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "tomario-${var.env}-rds-subnet-group"
  }
}

resource "aws_db_instance" "this" {
  identifier = "tomario-${var.env}-rds"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true

  allocated_storage = 20
  storage_type      = "gp2"

  port                   = 3306
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  auto_minor_version_upgrade = true
  deletion_protection        = false
  skip_final_snapshot        = true

  backup_retention_period = 1
  backup_window           = "18:00-19:00"
  maintenance_window      = "sun:19:00-sun:20:00"

  tags = {
    Name = "tomario-${var.env}-rds"
  }
}
