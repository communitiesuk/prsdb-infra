resource "aws_ecs_cluster" "main" {
  name = "${var.environment_name}-app"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

module "webapp_service" {
  source = "../fargate_service"

  name                              = "${var.environment_name}-app"
  cluster_arn                       = aws_ecs_cluster.main.arn
  task_definition_family            = "prsdb-webapp-${var.environment_name}"
  desired_count                     = var.webapp_task_desired_count
  allow_exec                        = var.allow_exec
  private_subnet_ids                = var.private_subnet_ids
  security_group_ids                = [aws_security_group.ecs.id]
  health_check_grace_period_seconds = 180 # The webapp can take ~2 minutes to start; give it time before ALB health checks can stop the task
  load_balancer = {
    container_name   = "prsdb-webapp"
    container_port   = var.application_port
    target_group_arn = var.lb_target_group_arn
  }
}

module "async_worker_service" {
  source = "../fargate_service"

  name                   = "${var.environment_name}-async-worker"
  cluster_arn            = aws_ecs_cluster.main.arn
  task_definition_family = "prsdb-async-worker-${var.environment_name}"
  desired_count          = var.async_worker_task_desired_count
  allow_exec             = var.allow_exec
  private_subnet_ids     = var.private_subnet_ids
  security_group_ids     = [aws_security_group.ecs.id]
}
