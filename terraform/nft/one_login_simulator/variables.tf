variable "environment_name" {
  description = "Environment name"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster for the simulator service"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the simulator tasks"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for the simulator networking resources"
  type        = string
}

variable "https_listener_arn" {
  description = "HTTPS listener ARN used for simulator host routing"
  type        = string
}

variable "simulator_alb_security_group_id" {
  description = "Security group ID attached to the simulator ALB ingress"
  type        = string
}

variable "vpc_endpoint_security_group_id" {
  description = "Security group ID for the AWS interface VPC endpoints"
  type        = string
}

variable "desired_count" {
  description = "Number of simulator tasks to run"
  type        = number

  validation {
    condition     = var.desired_count >= 0
    error_message = "The One Login simulator desired count must not be negative."
  }
}
