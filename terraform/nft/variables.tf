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
    condition     = var.one_login_simulator_desired_count >= 0
    error_message = "The One Login simulator desired count must not be negative."
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
