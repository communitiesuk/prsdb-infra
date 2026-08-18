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
  deployment_minimum_healthy_percent = 100 # There should always be at least the desired count running during a deployment
  desired_count                      = var.webapp_task_desired_count
  enable_execute_command             = var.allow_exec
  force_new_deployment               = true
  health_check_grace_period_seconds  = 180 # The webapp can take ~2 minutes to start; give it time before ALB health checks can stop the task
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  task_definition                    = "prsdb-webapp-${var.environment_name}" # Task family name - gets the latest ACTIVE revision

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
}
