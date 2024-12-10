#tfsec:ignore:aws-elb-alb-not-public:the load balancer must be exposed to the internet in order to communicate with cloudfront
resource "aws_lb" "main" {
  name                       = "alb-${var.environment_name}"
  drop_invalid_header_fields = true
  enable_deletion_protection = true
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.load_balancer.id]
  subnets                    = var.public_subnet_ids
}

resource "aws_lb_listener" "https" {
  count = var.ssl_certs_created ? 1 : 0

  certificate_arn   = var.load_balancer_certificate_arn
  load_balancer_arn = aws_lb.main.id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "403: Forbidden"
      status_code  = "403"
    }

    order = 50000 # this is the highest value possible so will be performed last out of all listener rules
  }
}

resource "aws_security_group" "load_balancer" {
  name        = "load-balancer-sg-${var.environment_name}"
  description = "Load Balancer security group"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "main" {
  name                          = var.environment_name
  port                          = var.application_port
  protocol                      = "HTTP"
  vpc_id                        = var.vpc_id
  target_type                   = "ip"
  load_balancing_algorithm_type = "least_outstanding_requests"
}

resource "aws_lb_listener_rule" "forward" {
  count = var.ssl_certs_created ? 1 : 0
  listener_arn = aws_lb_listener.https[count.index].arn

  action {
    target_group_arn = aws_lb_target_group.main.id
    type             = "forward"
  }

  condition {
    http_header {
      http_header_name = local.cloudfront_header_name
      values           = [random_password.cloudfront_header.result]
    }
  }
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_vpc_security_group_ingress_rule" "load_balancer_https_ingress" {
  description       = "Allow https ingress from cloudfront only"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  security_group_id = aws_security_group.load_balancer.id
}

# TODO: PRSD-574 - Reinstate when ECS has been configured
# resource "aws_vpc_security_group_egress_rule" "load_balancer_container_egress" {
#   description                  = "Allow egress to ecs"
#   ip_protocol                  = "tcp"
#   from_port                    = var.application_port
#   to_port                      = var.application_port
#   referenced_security_group_id = var.ecs_security_group_id
#   security_group_id            = aws_security_group.load_balancer.id
# }