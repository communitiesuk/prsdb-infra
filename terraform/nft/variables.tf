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

variable "maintenance_mode_on" {
  type        = bool
  description = "Indicates whether maintenance mode is on"
  default     = false
}