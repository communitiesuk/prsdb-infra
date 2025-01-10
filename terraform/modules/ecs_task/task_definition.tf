resource "aws_ecs_task_definition" "main" {
  family                   = "${var.task_name}-${var.environment_name}"
  cpu                      = var.task_cpu
  execution_role_arn       = var.ecs_task_execution_role_arn
  memory                   = var.task_memory #MiB
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.task_name
      essential = true
      image     = var.container_image
      user      = "nonroot"

      portMappings = [
        {
          protocol      = "tcp"
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]

      environment = var.environment_variables
      secrets     = var.secrets
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}