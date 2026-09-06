variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "One public subnet per AZ should serve"
  type        = list(any)
}

variable "internal" {
  type = bool
}

variable "allocate_eips" {
  description = "Allocate one Elastic IP per subnet (static IPs). Internet-facing only."
  type        = bool
}

variable "enable_cross_zone" {
  description = "NLB default is false and cross-AZ data is billed. Set this true for even distributions."
  type        = bool
}

variable "listener_port" {
  type = number
}

variable "listener_protocol" {
  description = "TCP, UDP, TCP_UDP or TLS. Must be TCP in alb mode."
  type        = string
  validation {
    condition     = contains(["TCP", "UDP", "TCP_UDP", "TLS"], var.listener_protocol)
    error_message = "listener_protocol must be TCP, UDP, TCP_UDP or TLS."
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN, required when listener_protocol = TLS"
  type        = string
  default     = null
}

variable "client_cidrs" {
  description = "CIDRs allowed to reach the listener. Also added to the target SG because client IP is preserved."
  type        = list(any)
}

variable "target_mode" {
  description = "alb = forward to an existing ALB (static-IP / PrivateLink pattern). asg = forward to an Auto Scaling Group running an L4 service."
  type        = string
  validation {
    condition     = contains(["alb", "asg"], var.target_mode)
    error_message = "target_mode must be alb or asg."
  }
}

variable "target_port" {
  description = "Port on the target. alb mode: must match an existing ALB listener port. asg mode: the service port (e.g. 9000)"
  type        = number
}

variable "target_protocol" {
  description = "asg mode only: TCP, UDP, TCP_UDP. alb mode is forced to TCP."
  type        = string
  validation {
    condition     = contains(["TCP", "UDP", "TCP_UDP"], var.target_protocol)
    error_message = "target_protocol must be TCP, UDP, TCP_UDP"
  }
}

variable "alb_arn" {
  type    = string
  default = null
}

variable "alb_listener_arn" {
  type    = string
  default = null
}

variable "asg_name" {
  type    = string
  default = null
}

variable "target_sg_id" {
  type    = string
  default = null
}

# ----------------- Health Check --------------

variable "health_check" {
  description = "alb mode: protocol must be HTTP/HTTPS. asg mode: TCP or HTTP. NLB accepts interval 10/30 only"
  type = object({
    protocol            = optional(string, "TCP")
    port                = optional(string, "traffic-port")
    path                = optional(string, "/")
    interval            = optional(number, 10)
    healthy_threshold   = optional(number, 2)
    unhealthy_threshold = optional(number, 2)
    matcher             = optional(string, "200-399")
  })
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}




