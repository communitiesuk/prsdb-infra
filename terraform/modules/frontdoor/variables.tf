variable "environment_name" {
  description = "must be one of: integration, test"
  type        = string
  validation {
    condition     = contains(["integration", "test"], var.environment_name)
    error_message = "Environment must be one of: integration, test"
  }
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "The ids of all the public subnets"
}

variable "load_balancer_certificate_arn" {
  type        = string
  description = "The arn of the certifcate to be associated with the load balancer HTTPS listener"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC to be associated with."
}

variable "application_port" {
  type        = number
  description = "The network port the application runs on"
}

variable "ecs_security_group_id" {
  type        = string
  description = "The id of the ecs security group for ecs egress"
}