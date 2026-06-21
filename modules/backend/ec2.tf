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

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log) 2>&1

    dnf update -y
    dnf install -y git python3-pip mariadb105

    RDS_ID="tomario-${var.env}-rds"

    DB_HOST=$(aws rds describe-db-instances \
      --db-instance-identifier "$RDS_ID" \
      --query 'DBInstances[0].Endpoint.Address' \
      --output text --region ap-northeast-1)

    SECRET_ARN=$(aws rds describe-db-instances \
      --db-instance-identifier "$RDS_ID" \
      --query 'DBInstances[0].MasterUserSecret.SecretArn' \
      --output text --region ap-northeast-1)

    SECRET=$(aws secretsmanager get-secret-value \
      --secret-id "$SECRET_ARN" \
      --region ap-northeast-1 \
      --query SecretString \
      --output text)

    DB_USER=$(echo "$SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
    DB_PASS=$(echo "$SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

    git clone https://github.com/Tomario-portfolio/tomario-app.git /opt/tomario-app
    cd /opt/tomario-app
    pip3 install -r requirements.txt

    printf "SECRET_KEY=%s\nDB_HOST=%s\nDB_PORT=3306\nDB_NAME=tomario\nDB_USER=%s\nDB_PASSWORD=%s\n" \
      "$(openssl rand -hex 32)" "$DB_HOST" "$DB_USER" "$DB_PASS" \
      > /opt/tomario-app/.env

    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" < /opt/tomario-app/schema.sql || true

    {
    echo '[Unit]'
    echo 'Description=Tomario Flask App'
    echo 'After=network.target'
    echo ''
    echo '[Service]'
    echo 'User=root'
    echo 'WorkingDirectory=/opt/tomario-app'
    echo 'EnvironmentFile=/opt/tomario-app/.env'
    echo 'ExecStart=/usr/bin/python3 app.py'
    echo 'Restart=always'
    echo 'RestartSec=5'
    echo ''
    echo '[Install]'
    echo 'WantedBy=multi-user.target'
    } > /etc/systemd/system/tomario.service

    systemctl daemon-reload
    systemctl enable tomario
    systemctl start tomario
  EOT
  )

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
