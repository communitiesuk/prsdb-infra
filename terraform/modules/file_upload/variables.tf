variable "environment_name" {
  description = "must be one of: integration, test, nft, or production"
  type        = string
  validation {
    condition     = contains(["integration", "test", "nft", "production"], var.environment_name)
    error_message = "Environment must be one of: integration, test"
  }
}

variable "webapp_task_execution_role_name" {
  description = "Name of the IAM role for the webapp ECS task execution"
  type        = string
}

variable "async_worker_ecs_task_role_name" {
  description = "Name of the async worker ECS task role, which processes scan results from the scan result queue"
  type        = string
}

variable "non_critical_alarm_sns_topic_arn" {
  description = "ARN of the SNS topic that non-critical scan result queue alarms notify, or null while the environment's monitoring has not been created"
  type        = string
  default     = null
}

variable "critical_alarm_sns_topic_arn" {
  description = "ARN of the SNS topic that critical scan result queue alarms notify, or null while the environment's monitoring has not been created"
  type        = string
  default     = null
}