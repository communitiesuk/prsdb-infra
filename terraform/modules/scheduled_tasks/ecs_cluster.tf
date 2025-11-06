#tfsec:ignore:aws-ecs-enable-container-insight: We can enable insights later if required
resource "aws_ecs_cluster" "scheduled_tasks" {
  name = "${var.environment_name}-scheduled-tasks"
}



