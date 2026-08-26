data "aws_caller_identity" "current" {}
# ===============
# S3 for ALB Logs
# ===============
data "aws_elb_service_account" "main" {}

# trivy:ignore:AWS-0132 -- SSE-S3 sufficient for disposable dev access-log bucket, same reasoning as CKV_AWS_145
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "alb-project-logs-dev-${data.aws_caller_identity.current.account_id}-051"
  force_destroy = true

  tags = {
    Name      = "alb-project-logs"
    Project   = "alb-project"
    Owner     = "Pietro"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# =======================================
# Target Group Definition & Health Checks
# =======================================
resource "aws_lb_target_group" "web_tg" {
  name        = "${var.project_name}-web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name      = "${var.project_name}-web-tg"
    Project   = var.project_name
    Owner     = var.owner
    ManagedBy = "terraform"
  }
}

# =====================================
# Application load balancer & Listeners
# =====================================
# trivy:ignore:AWS-0053 -- Intentionally internet-facing ALB, entry point for public web traffic
resource "aws_lb" "main_alb" {
  name               = "${var.project_name}-main-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.web_subnet_ids

  enable_deletion_protection = false
  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    enabled = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

