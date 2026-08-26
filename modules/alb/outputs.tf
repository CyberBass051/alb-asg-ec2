output "lb_target_group_arn" {
  value = aws_lb_target_group.web_tg.arn
}

output "lb_arn" {
  value = aws_lb.main_alb.arn
}