output "alb_dns_name" {
  value = module.backend.alb_dns_name
}

output "alb_sg_id" {
  value = module.backend.alb_sg_id
}

output "ecs_sg_id" {
  value = module.backend.ecs_sg_id
}

output "target_group_arn" {
  value = module.backend.target_group_arn
}

output "alb_arn_suffix" {
  value = module.backend.alb_arn_suffix
}

output "target_group_arn_suffix" {
  value = module.backend.target_group_arn_suffix
}

output "ecs_service_name" {
  value = module.backend.ecs_service_name
}

output "origin_verify_header_value" {
  value     = random_password.origin_verify.result
  sensitive = true
}
