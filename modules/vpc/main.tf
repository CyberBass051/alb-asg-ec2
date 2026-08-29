data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms_flow_logs" {
  statement {
    sid       = "EnableRootAccountAccess"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowCloudWatchLogsEncryption"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }
}
# =================
# 1. VPC Definition
# =================
resource "aws_vpc" "alb_vpc" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "${var.project_name}-alb-vpc"
    Project   = var.project_name
    Owner     = var.owner
    ManagedBy = "terraform"
  }
}

# ==================
# Subnets Definition
# ==================

locals {
  subnets = merge([
    for tier, cfg in var.tier_config : {
      for idx, az in var.azs :
      "${tier}-${az}" => {
        tier                    = tier
        az                      = az
        cidr                    = cidrsubnet(var.vpc_cidr, 8, cfg.cidr_offset + idx)
        map_public_ip_on_launch = cfg.map_public_ip
      }
    }
  ]...)
}
# trivy:ignore:AWS-0164 -- Public subnet is exclusively for the internet-facing ALB, which requires a public IP to receive traffic. No compute (EC2/ECS) is deployed here.
resource "aws_subnet" "this" {
  for_each                = local.subnets
  vpc_id                  = aws_vpc.alb_vpc.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  tags = {
    Name      = "${var.project_name}-${each.key}"
    Tier      = each.value.tier
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# =======================
# Create Internet Gateway
# =======================
resource "aws_internet_gateway" "alb_igw" {
  vpc_id = aws_vpc.alb_vpc.id

  tags = {
    Name      = "${var.project_name}-igw"
    Project   = var.project_name
    Owner     = var.owner
    ManagedBy = "terraform"

  }
}

# =================================
# Create and Associate Route Tables
# =================================

resource "aws_route_table" "this" {
  for_each = var.route_config
  vpc_id   = aws_vpc.alb_vpc.id

  tags = {
    Name      = "${var.project_name}-${each.key}-rt"
    Project   = var.project_name
    Owner     = var.owner
    ManagedBy = "terraform"
  }
}

resource "aws_route_table_association" "this" {
  for_each       = local.subnets
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.value.tier].id
}

resource "aws_route" "public_igw" {
  for_each               = { for k, v in var.route_config : k => v if v.public }
  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.alb_igw.id
}

# ========================
# Elastic IP & NAT Gateway
# ========================
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.alb_igw]

  tags = {
    Name      = "${var.project_name}-eip"
    Project   = var.project_name
    Owner     = var.owner
    ManagedBy = "terraform"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.this["web-us-east-1a"].id

  tags = {
    Name      = "${var.project_name}-nat-gw"
    Project   = var.project_name
    Owner     = var.owner
    ManagedBy = "terraform"
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.this["app"].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

# =============
# VPC Flow Logs
# =============
resource "aws_kms_key" "flow_logs" {
  description             = "KMS for VPC Flow Logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.kms_flow_logs.json

  tags = {
    Name      = "${var.project_name}-flow-logs-kms"
    Project   = var.project_name
    Owner     = var.owner
    ManagedBy = "terraform"
  }
}

resource "aws_kms_alias" "flow_logs" {
  name          = "alias/${var.project_name}-flow-logs"
  target_key_id = aws_kms_key.flow_logs.key_id
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.project_name}-flow-logs"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.flow_logs.arn

  tags = {
    Name      = "${var.project_name}-kms-flow-logs"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  role = aws_iam_role.flow_logs.id
  name = "${var.project_name}-flow-logs-role-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LogsManager"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "vpc_flow_logs" {
  vpc_id               = aws_vpc.alb_vpc.id
  traffic_type         = "ALL"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  iam_role_arn         = aws_iam_role.flow_logs.arn
}

resource "aws_default_security_group" "alb_vpc_default" {
  vpc_id = aws_vpc.alb_vpc.id


  tags = {
    Name      = "${var.project_name}-default-sg-locked"
    Project   = var.project_name
    Owner     = var.owner
    ManagedBy = "terraform"
  }
}