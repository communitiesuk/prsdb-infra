variable "environment_name" {
  type = string
}

variable "ecs_task_execution_role_arn" {
  type = string
}

variable "one_login_client_id" {
  type = string
}

variable "one_login_public_key" {
  type      = string
  sensitive = true
}
