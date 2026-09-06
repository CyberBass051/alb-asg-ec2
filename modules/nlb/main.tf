locals {
  alb_mode        = var.target_mode == "alb"
  tg_protocol     = local.alb_mode ? "TCP" : var.target_protocol
  hc_protocol     = local.alb_mode && var.health_check.protocol == "TCP" ? "HTTP" : var.health_check.protocol
  hc_is_http      = contains(["HTTPS", "HTTP"], local.hc_protocol)
  use_eips        = var.allocate_eips && !var.internal
  udp_listener    = contains(["UDP", "TCP_UDP"], var.listener_protocol)
  sg_ip_protocols = local.udp_listener ? ["tcp", "udp"] : ["tcp"]
}

locals {
  target_ip_protocols = local.alb_mode ? ["tcp"] : (
    contains(["UDP", "TCP_UDP"], local.tg_protocol) ? ["tcp", "udp"] : ["tcp"]
  )
  target_client_rules = var.target_sg_id == null ? {} : {
    for pair in setproduct(local.target_ip_protocols, var.client_cidrs) :
    "${pair[0]}-${pair[1]}" => { protocol = pair[0], cidr = pair[1] }
  }
}

# ==============
# Security Group
# ==============

resource "aws_security_group" "nlb" {
  name        = "${var.project_name}-nlb-sg"
  description = "Ingress for NLB ${var.project_name}"
  vpc_id      = var.vpc_id
  tags = merge(var.tags, {
    Name      = "${var.project_name}-nlb-sg"
    Project   = var.project_name
    ManagedBy = "terraform"
  })
}

resource "aws_vpc_security_group_ingress_rule" "nlb_clients" {
  for_each = { for pair in setproduct(local.sg_ip_protocols, var.client_cidrs) : "${pair[0]}-${pair[1]}" => pair }

  security_group_id = aws_security_group.nlb.id
  ip_protocol       = each.value[0]
  from_port         = var.listener_port
  to_port           = var.listener_port
  cidr_ipv4         = each.value[1]
  description       = "Allows Ingress for port ${var.listener_port}"
}

resource "aws_vpc_security_group_egress_rule" "nlb_clients" {
  security_group_id = aws_security_group.nlb.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allows all traffic outbound"
}

# ===========
# Static IPs
# ===========

resource "aws_eip" "this" {
  count  = local.use_eips ? length(var.subnet_ids) : 0
  domain = "vpc"
  tags = merge(var.tags, {
    Name      = "${var.project_name}-nlb-eip-${count.index}"
    Project   = var.project_name
    ManagedBy = "terraform"
  })

}

# ==============
# Load Balancer
# ==============

resource "aws_lb" "this" {
  name               = "${var.project_name}-nlb"
  load_balancer_type = "network"
  internal           = var.internal
  security_groups    = [aws_security_group.nlb.id]

  enable_cross_zone_load_balancing = var.enable_cross_zone

  dynamic "subnet_mapping" {
    for_each = { for i, s in var.subnet_ids : i => s }
    content {
      subnet_id     = subnet_mapping.value
      allocation_id = local.use_eips ? aws_eip.this[subnet_mapping.key].id : null
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-nlb"
    Project   = var.project_name
    ManagedBy = "terraform"
  })
}

# ===============
# Target Group
# ================

resource "aws_lb_target_group" "this" {
  name        = "${var.project_name}-nlb-tg"
  vpc_id      = var.vpc_id
  target_type = local.alb_mode ? "alb" : "instance"
  protocol    = local.tg_protocol
  port        = var.target_port

  # asg mode only; ignored for alb targets. UDP forces preservation anyway.
  preserve_client_ip = local.alb_mode ? null : "true"

  health_check {
    protocol            = var.health_check.protocol
    port                = var.health_check.port
    path                = local.hc_is_http ? var.health_check.path : null
    matcher             = local.hc_is_http ? var.health_check.matcher : null
    interval            = var.health_check.interval
    healthy_threshold   = var.health_check.healthy_threshold
    unhealthy_threshold = var.health_check.unhealthy_threshold
  }

  # alb-type target groups are immutable; force replacement instead of falling on failing on apply
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}"
    Project   = var.project_name
    ManagedBy = "terraform"
  })
}

resource "aws_lb_target_group_attachment" "alb" {
  count            = local.alb_mode ? 1 : 0
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.alb_arn
  port             = var.target_port

  depends_on = [aws_lb_listener.this]
  lifecycle {
    precondition {
      condition     = var.alb_arn != null && var.alb_listener_arn != null
      error_message = "alb mode requires alb_arn and alb_listener_arn."
    }
  }
}

# asg mode: attach the ASG so new instances register automatically
resource "aws_autoscaling_traffic_source_attachment" "asg" {
  count                  = local.alb_mode ? 0 : 1
  autoscaling_group_name = var.asg_name

  traffic_source {
    identifier = aws_lb_target_group.this.arn
    type       = "elbv2"
  }

  lifecycle {
    precondition {
      condition     = var.asg_name != null
      error_message = "asg mode requires asg_name."
    }
  }
}

# ============
# Listener
# ===========

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = var.listener_protocol
  certificate_arn   = var.listener_protocol == "TLS" ? var.certificate_arn : null
  ssl_policy        = var.listener_protocol == "TLS" ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# =================
# Rules the TG needs
# =================

resource "aws_vpc_security_group_ingress_rule" "target_from_clients" {
  for_each          = local.target_client_rules
  security_group_id = var.target_sg_id
  ip_protocol       = each.value[0]
  from_port         = var.target_port
  to_port           = var.target_port
  cidr_ipv4         = each.value[1]
  description       = "NLC ${var.project_name}: preserved client IP"
}

resource "aws_vpc_security_group_ingress_rule" "target_healthcheck_from_nlb" {
  count = var.target_sg_id == null ? 0 : 1

  security_group_id            = var.target_sg_id
  ip_protocol                  = "tcp"
  from_port                    = var.health_check.port == "traffic-port" ? var.target_port : tonumber(var.health_check.port)
  to_port                      = var.health_check.port == "traffic-port" ? var.target_port : tonumber(var.health_check.port)
  referenced_security_group_id = aws_security_group.nlb.id
  description                  = "NLB ${var.project_name}: health checks"
}
