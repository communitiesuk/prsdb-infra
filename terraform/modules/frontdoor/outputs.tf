output "load_balancer" {
  value = {
    arn               = aws_lb.main.arn
    arn_suffix        = aws_lb.main.arn_suffix
    dns_name          = aws_lb.main.dns_name
    listener_arn      = var.ssl_certs_created ? aws_lb_listener.https[0].arn : null
    security_group_id = aws_security_group.load_balancer.id
  }
}

output "cloudfront_dns_name" {
  value = aws_cloudfront_distribution.main.domain_name
}