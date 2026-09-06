output "certificate_arn" {
  value = aws_acm_certificate.web.arn
}

output "https_listener_arn" {
  value = aws_lb_listener.https.arn 
}