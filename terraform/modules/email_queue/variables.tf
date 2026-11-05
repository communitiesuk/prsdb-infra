variable "environment_name" {
  description = "must be one of: integration, test, nft, or production"
  type        = string
  validation {
    condition     = contains(["integration", "test", "nft", "production"], var.environment_name)
    error_message = "Environment must be one of: integration, test, nft, or production"
  }
}

variable "webapp_ecs_task_role_name" {
  description = "Name of the webapp ECS task role, which sends emails to the queue"
  type        = string
}

variable "email_worker_ecs_task_role_name" {
  description = "Name of the email worker ECS task role, which consumes the queue"
  type        = string
}

variable "non_critical_alarm_sns_topic_arn" {
  description = "ARN of the SNS topic that non-critical email queue alarms notify, or null while the environment's monitoring has not been created"
  type        = string
  default     = null
}

variable "critical_alarm_sns_topic_arn" {
  description = "ARN of the SNS topic that critical email queue alarms notify, or null while the environment's monitoring has not been created"
  type        = string
  default     = null
}
