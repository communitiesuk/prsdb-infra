variable "environment_name" {
  description = "must be one of: integration, test, nft, or production"
  type        = string
  validation {
    condition     = contains(["integration", "test", "nft", "production"], var.environment_name)
    error_message = "Environment must be one of: integration, test, nft, or production"
  }
}

variable "alarm_email_address" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
}

variable "cloudwatch_log_expiration_days" {
  type        = number
  description = "Number of days to retain cloudwatch logs for"
}