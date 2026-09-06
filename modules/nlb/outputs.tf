output "nlb_arn" {
  value = aws_lb.this.arn
}

output "nlb_dns_name" {
  value = aws_lb.this.dns_name
}

output "nlb_zone_id" {
  value = aws_lb.this.zone_id
}

output "nlb_security_group_id" {
  value = aws_security_group.nlb.id
}

output "static_ips" {
  description = "Elastic IPs, one per subnet, when allocate_eips = true"
  value       = aws_eip.this[*].public_ip
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}
