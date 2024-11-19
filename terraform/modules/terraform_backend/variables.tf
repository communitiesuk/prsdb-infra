variable "environment_name" {
  description = "must be one of: integration, test"
  type        = string
  validation {
    condition     = contains(["integration", "test"], var.environment_name)
    error_message = "Environment must be one of: integration, test"
  }
}