output "rds_endpoint" {
  value = module.database.rds_endpoint
}

output "rds_address" {
  value = module.database.rds_address
}

output "rds_sg_id" {
  value = module.database.rds_sg_id
}

output "master_user_secret_arn" {
  value = module.database.master_user_secret_arn
}

output "db_instance_identifier" {
  value = module.database.db_instance_identifier
}
