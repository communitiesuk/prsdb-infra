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

variable "host_header" {
  description = "Load balancer host header the simulator listener rule matches on"
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
    # The simulator caches auth flows in memory, so it only supports running as a singleton - if requests within
    # the same auth flow reach different instances, authentication will fail.
    condition     = var.desired_count >= 0 && var.desired_count <= 1
    error_message = "The One Login simulator desired count must be 0 or 1; the simulator does not support running more than one instance."
  }
}
