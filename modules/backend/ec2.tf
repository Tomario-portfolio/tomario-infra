# このファイルはECS移行により不要になりました。ecs.tfを参照してください。

# data "aws_ami" "amazon_linux_2023" {（旧）
#   most_recent = true
#   owners      = ["amazon"]
#   filter {
#     name   = "name"
#     values = ["al2023-ami-*-x86_64"]
#   }
# }
#
# resource "aws_launch_template" "this" {
#   name          = "tomario-${var.env}-lt"
#   image_id      = data.aws_ami.amazon_linux_2023.id
#   instance_type = var.instance_type
#   iam_instance_profile { name = aws_iam_instance_profile.ec2.name }
#   vpc_security_group_ids = [aws_security_group.ec2.id]
#   user_data = base64encode(<<-EOT
#     #!/bin/bash
#     ...Flaskアプリ自動セットアップ...
#   EOT)
# }
#
# resource "aws_autoscaling_group" "this" {
#   name                = "tomario-${var.env}-asg"
#   max_size            = 1
#   min_size            = 1
#   desired_capacity    = 1
#   vpc_zone_identifier = var.public_subnet_ids
#   launch_template {
#     id      = aws_launch_template.this.id
#     version = "$Latest"
#   }
#   target_group_arns         = [aws_lb_target_group.this.arn]
#   health_check_type         = "ELB"
#   health_check_grace_period = 300
# }
