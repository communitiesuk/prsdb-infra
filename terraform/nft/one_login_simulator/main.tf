terraform {
  required_version = "~>1.9.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}

resource "aws_lb_target_group" "simulator" {
  name        = "one-login-simulator-${var.environment_name}"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
  }
}

resource "aws_lb_listener_rule" "simulator" {
  listener_arn = var.https_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.simulator.arn
  }

  condition {
    host_header {
      values = ["nft.lb.register-home-to-rent.test.communities.gov.uk"]
    }
  }
}

resource "aws_security_group" "simulator" {
  name        = "${var.environment_name}-one-login-simulator"
  description = "One Login simulator ECS task security group"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_simulator_alb" {
  description                  = "Allow simulator traffic from the simulator ALB security group"
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = var.simulator_alb_security_group_id
  security_group_id            = aws_security_group.simulator.id
}

resource "aws_vpc_security_group_egress_rule" "https" {
  description                  = "Allow simulator HTTPS access to external dependencies"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = var.vpc_endpoint_security_group_id
  security_group_id            = aws_security_group.simulator.id
}

resource "aws_vpc_security_group_egress_rule" "simulator_alb_to_task" {
  description                  = "Allow the simulator ALB to reach simulator tasks"
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = aws_security_group.simulator.id
  security_group_id            = var.simulator_alb_security_group_id
}

resource "aws_ecs_service" "simulator" {
  name                               = "${var.environment_name}-one-login-simulator"
  cluster                            = var.ecs_cluster_arn
  desired_count                      = var.desired_count
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  task_definition                    = "prsdb-one-login-simulator-${var.environment_name}"
  health_check_grace_period_seconds  = 60
  force_new_deployment               = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  load_balancer {
    container_name   = "prsdb-one-login-simulator"
    container_port   = 3000
    target_group_arn = aws_lb_target_group.simulator.arn
  }

  network_configuration {
    security_groups  = [aws_security_group.simulator.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }
}
