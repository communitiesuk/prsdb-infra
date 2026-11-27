variable "ssl_certs_created" {
  description = "Indicates whether ssl certificates have already been manually created"
  type        = bool
  default     = true
}

variable "task_definition_created" {
  description = "Indicates whether the initial task definition has been created"
  type        = bool
  default     = true
}

variable "one_login_simulator_desired_count" {
  description = "Number of One Login simulator tasks to run in NFT"
  type        = number
  default     = 0

  validation {
    # The simulator caches auth flows in memory, so it only supports running as a singleton - if requests within
    # the same auth flow reach different instances, authentication will fail.
    condition     = var.one_login_simulator_desired_count >= 0 && var.one_login_simulator_desired_count <= 1
    error_message = "The One Login simulator desired count must be 0 or 1; the simulator does not support running more than one instance."
  }
}

variable "webapp_scaling_min_capacity" {
  description = "Minimum NFT webapp task count"
  type        = number
  default     = 2
  validation {
    condition     = var.webapp_scaling_min_capacity >= 1 && floor(var.webapp_scaling_min_capacity) == var.webapp_scaling_min_capacity
    error_message = "The minimum task count must be a positive integer."
  }
}

variable "webapp_scaling_max_capacity" {
  description = "Maximum NFT webapp task count"
  type        = number
  default     = 15
  validation {
    condition     = var.webapp_scaling_max_capacity >= 1 && floor(var.webapp_scaling_max_capacity) == var.webapp_scaling_max_capacity
    error_message = "The maximum task count must be a positive integer."
  }
}

variable "webapp_scaling_cpu_target" {
  description = "Target average NFT webapp CPU utilization percentage"
  type        = number
  default     = 60
  validation {
    condition     = var.webapp_scaling_cpu_target > 0 && var.webapp_scaling_cpu_target <= 100
    error_message = "The CPU target must be greater than zero and at most 100."
  }
}

variable "critical_alarm_email_address" {
  description = "Email address to receive critical CloudWatch alarm notifications"
  type        = string
  sensitive   = true
}

variable "non_critical_alarm_email_address" {
  description = "Email address to receive non-critical CloudWatch alarm notifications"
  type        = string
  sensitive   = true
}

variable "enable_kms_cloudtrail_events" {
  type        = bool
  description = "Whether to log KMS  events to CloudTrail"
  default     = false
}

variable "maintenance_mode_on" {
  type        = bool
  description = "Indicates whether maintenance mode is on"
  default     = false
}
