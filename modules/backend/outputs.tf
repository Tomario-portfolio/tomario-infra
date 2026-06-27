output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "ecs_sg_id" {
  value = aws_security_group.ecs.id
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.this.arn_suffix
}

output "ecs_service_name" {
  value = aws_ecs_service.this.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.this.repository_url
}

# output "ec2_sg_id" {（旧）
#   value = aws_security_group.ec2.id
# }
#
# output "asg_name" {（旧）
#   value = aws_autoscaling_group.this.name
# }
