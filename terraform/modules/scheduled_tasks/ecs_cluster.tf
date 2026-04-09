resource "aws_ecs_cluster" "scheduled_tasks" {
  name = "${var.environment_name}-scheduled-tasks"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}



