output "rds_endpoint" {
  value = aws_db_instance.this.endpoint
}

output "rds_address" {
  value = aws_db_instance.this.address
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "master_user_secret_arn" {
  value = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "db_instance_identifier" {
  value = aws_db_instance.this.identifier
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}
