# ===================================================
# ALB security group allowing HTTP & HTTPS traffic in
# ===================================================
resource "aws_security_group" "alb_sg" {
  name        = "main-alb-sg"
  description = "Controls public web access to the Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name      = "main-alb-sg"
    Project   = var.project_name
    Owner     = "Pietro"
    ManagedBy = "terraform"
  }
}

resource "aws_security_group_rule" "alb_allow_http" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  description       = "Allow public HTTP traffic"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
}

resource "aws_security_group_rule" "alb_allow_https" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  description       = "Allow public HTTPs traffic"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
}

# ============================================
# Web Instance Security Group (Private Backend)
# ============================================
resource "aws_security_group" "web_sg" {
  name        = "main-web-sg"
  description = "Control access to private backend/containers"
  vpc_id      = var.vpc_id

  tags = {
    Name      = "main-web-sg"
    Project   = var.project_name
    Owner     = "Pietro"
    ManagedBy = "terraform"
  }
}

resource "aws_security_group_rule" "web_from_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.web_sg.id
  description              = "Allow HTTP strictly from ALB"
  source_security_group_id = aws_security_group.alb_sg.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "web_allow_outbound_https" {
  type              = "egress"
  security_group_id = aws_security_group.web_sg.id
  description       = "Allow outbound HTTPS for software updates and APIs"
  cidr_blocks       = [var.vpc_cidr]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
}

## ==========================
## SG for interface endpoints
## ==========================
#resource "aws_security_group" "vpce_sg" {
#  name        = "main-vpce-sg"
#  description = "Allow private services to reach interface endpoints"
#  vpc_id      = var.vpc_id
#
#  tags = {
#    Name      = "main-vpce-sg"
#    Project   = var.project_name
#    Owner     = "Pietro"
#    ManagedBy = "terraform"
#  }
#}
#
#resource "aws_security_group_rule" "vpce_from_web" {
#  type                         = "ingress"
#  security_group_id            = aws_security_group.vpce_sg.id
#  description                  = "Allow HTTPS ingress to VPC Enpoints from Web SG only"
#  source_security_group_id     = aws_security_group.web_sg.id
#  from_port                    = 443
#  to_port                      = 443
#  protocol                     = "tcp"
#}

