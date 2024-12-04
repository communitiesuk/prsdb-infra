output "load_balancer" {
  value = {
    arn               = aws_lb.main.arn
    arn_suffix        = aws_lb.main.arn_suffix
    listener_arn      = aws_lb_listener.https.arn
    security_group_id = aws_security_group.load_balancer.id
  }
}