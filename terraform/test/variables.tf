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

variable "alarm_email_address" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  sensitive   = true
}

variable "use_aws_shield_advanced" {
  description = "Indicates whether AWS Shield Advanced should be enabled"
    type        = bool
    default     = false
}