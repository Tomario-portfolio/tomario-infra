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
  engine_version = "8.4"
  instance_class = var.instance_class

  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true

  allocated_storage = 20
  # ストレージ自動拡張の上限（GB）。0は自動拡張なし
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  port                   = 3306
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  allow_major_version_upgrade = true
  auto_minor_version_upgrade  = true
  deletion_protection         = false
  skip_final_snapshot         = var.skip_final_snapshot
  # destroy時に残す最終スナップショット名。同名のスナップショットが既にあるとdestroyが失敗するため、
  # 一度destroyして再作成した後に再びdestroyする場合は、先に古い最終スナップショットを削除しておく
  final_snapshot_identifier = var.skip_final_snapshot ? null : "tomario-${var.env}-rds-final"

  backup_retention_period = 7
  backup_window           = "18:00-19:00"
  maintenance_window      = "sun:19:00-sun:20:00"

  tags = {
    Name = "tomario-${var.env}-rds"
  }
}
