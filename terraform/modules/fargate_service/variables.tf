variable "name" {
  description = "Name of the ECS service"
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster to run the service in"
  type        = string
}

variable "task_definition_family" {
  description = "Task definition family; the service runs its latest ACTIVE revision"
  type        = string
}

variable "desired_count" {
  description = "Target number of tasks to run"
  type        = number
}

variable "allow_exec" {
  description = "Whether to enable AWS ECS Exec on the tasks"
  type        = bool
}

variable "private_subnet_ids" {
  description = "List of subnet ids to deploy the tasks to"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups to attach to the tasks"
  type        = list(string)
}

variable "load_balancer" {
  description = "Load balancer target to register tasks with, or null for services that receive no inbound traffic"
  type = object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  })
  default = null
}

variable "health_check_grace_period_seconds" {
  description = "Time to ignore load balancer health checks after a task starts; only valid with a load balancer"
  type        = number
  default     = null
}
