resource "aws_ecs_cluster" "main" {
  name = "${var.environment_name}-app"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_service" "webapp" {
  name                               = "${var.environment_name}-app"
  cluster                            = aws_ecs_cluster.main.arn
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = var.webapp_task_desired_count
  enable_execute_command             = var.allow_exec
  force_new_deployment               = true
  health_check_grace_period_seconds  = 180
  launch_type                        = "FARGATE"
  availability_zone_rebalancing      = var.availability_zone_rebalancing
  scheduling_strategy                = "REPLICA"
  task_definition                    = "prsdb-webapp-${var.environment_name}"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  load_balancer {
    container_name   = "prsdb-webapp"
    container_port   = var.application_port
    target_group_arn = var.lb_target_group_arn
  }

  network_configuration {
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

moved {
  from = module.webapp_service.aws_ecs_service.main
  to   = aws_ecs_service.webapp
}

module "async_worker_service" {
  source = "../fargate_service"

  name                          = "${var.environment_name}-async-worker"
  cluster_arn                   = aws_ecs_cluster.main.arn
  task_definition_family        = "prsdb-async-worker-${var.environment_name}"
  desired_count                 = var.async_worker_task_desired_count
  availability_zone_rebalancing = var.availability_zone_rebalancing
  allow_exec                    = var.allow_exec
  private_subnet_ids            = var.private_subnet_ids
  security_group_ids            = [aws_security_group.ecs.id]
}
