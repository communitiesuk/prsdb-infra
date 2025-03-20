variable "environment_name" {
  description = "must be one of: integration, test"
  type        = string
  validation {
    condition     = contains(["integration", "test"], var.environment_name)
    error_message = "Environment must be one of: integration, test"
  }
}

variable "webapp_task_execution_role_name" {
  description = "Name of the IAM role for the webapp ECS task execution"
  type        = string
}