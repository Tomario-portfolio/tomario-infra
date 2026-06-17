data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ------------------------------------------------------------
# Security Groups
# ------------------------------------------------------------

resource "aws_security_group" "alb" {
  name   = "tomario-${var.env}-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tomario-${var.env}-alb-sg"
  }
}

resource "aws_security_group" "ec2" {
  name   = "tomario-${var.env}-ec2-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tomario-${var.env}-ec2-sg"
  }
}

# ------------------------------------------------------------
# IAM
# ------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "tomario-${var.env}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "tomario-${var.env}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "secrets_read" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "secrets_read" {
  name   = "tomario-${var.env}-secrets-read"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.secrets_read.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "tomario-${var.env}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name = "tomario-${var.env}-ec2-profile"
  }
}

# ------------------------------------------------------------
# ALB
# ------------------------------------------------------------

resource "aws_lb" "this" {
  name               = "tomario-${var.env}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "tomario-${var.env}-alb"
  }
}

resource "aws_lb_target_group" "this" {
  name     = "tomario-${var.env}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "tomario-${var.env}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# ------------------------------------------------------------
# Launch Template & ASG
# ------------------------------------------------------------

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
}
