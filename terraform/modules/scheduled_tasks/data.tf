# Use Resource Groups Tagging API to find all ECS task definitions tagged with task-type=scheduled
data "aws_ecs_task_definition" "scheduled_tasks" {
  for_each        = var.scheduled_tasks
  task_definition = "prsdb-${each.key}-scheduled-task-${var.environment_name}"
}

locals {
  tasks = {
    for key, task_def in data.aws_ecs_task_definition.scheduled_tasks :
    key => {
      task_family_arn     = task_def.arn_without_revision
      schedule_expression = var.scheduled_tasks[key].schedule_expression
    }
  }

}