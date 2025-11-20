# Use Resource Groups Tagging API to find all ECS task definitions tagged with task-type=scheduled
data "aws_resourcegroupstaggingapi_resources" "scheduled_task_definitions" {
  tag_filter {
    key    = "Type"
    values = ["scheduled-task"]
  }

  resource_type_filters = ["ecs:task-definition"]
}

locals {
  unique_task_names = distinct([
    for task_def in data.aws_resourcegroupstaggingapi_resources.scheduled_task_definitions.resource_tag_mapping_list :
    task_def.tags["ScheduledTaskName"]
  ])
  tasks = {
    for task_name in local.unique_task_names :
    task_name => {
      # We can assume that there is only one task definition family per ScheduledTaskName
      task_family_arn = replace(
        [
          for task_def in data.aws_resourcegroupstaggingapi_resources.scheduled_task_definitions.resource_tag_mapping_list :
          task_def.resource_arn if task_def.tags["ScheduledTaskName"] == task_name
        ][0],
        "/:[0-9]+$/",
        ""
      )
      schedule_expression = var.schedule_expressions[task_name].schedule_expression
    }
  }
}
