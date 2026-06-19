data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "this" {
  name          = "tomario-${var.env}-lt"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # ASGで起動したEC2にはproviderのdefault_tagsが伝播しないため明示的に指定
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "tomario-${var.env}-ec2"
      Project     = "tomario"
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }

  tags = {
    Name = "tomario-${var.env}-lt"
  }
}

resource "aws_autoscaling_group" "this" {
  name                = "tomario-${var.env}-asg"
  max_size            = 1
  min_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = var.public_subnet_ids

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.this.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "tomario-${var.env}-asg"
    propagate_at_launch = false
  }

  timeouts {
    delete = "20m"
  }
}
