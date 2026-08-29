# ===========================
# ASG Target Group Attachment
# ===========================
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al-2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "web" {
  name_prefix            = "${var.project_name}-web-"
  image_id               = data.aws_ami_al2023.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [var.web_sg_id]
  user_data              = base64encode(file("${path.module}/user-data.sh"))

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}

resource "aws_autoscaling_group" "web" {
  name                = "${var.project_name}-web-asg"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = var.app_subnet_ids
  target_group_arns   = [var.lb_target_group_arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  health_check_type         = "ELB"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_scaling_policy" {
  name                   = "target-tracking-cpu-50"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.web.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    taget_value = 50.0
  }
}