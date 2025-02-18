output "load_balancer" {
  description = "An object representing the application load balancer"
  value = {
    arn               = aws_lb.main.arn
    arn_suffix        = aws_lb.main.arn_suffix
    dns_name          = aws_lb.main.dns_name
    listener_arn      = var.ssl_certs_created ? aws_lb_listener.https[0].arn : null
    security_group_id = aws_security_group.load_balancer.id
    target_group_arn  = aws_lb_target_group.main.arn
  }
}

output "cloudfront_dns_name" {
  description = "The domain name of the cloudfront distribution"
  value       = aws_cloudfront_distribution.main.domain_name
}