variable "environment_name" {
  description = "must be one of: integration, test"
  type        = string
  validation {
    condition     = contains(["integration", "test"], var.environment_name)
    error_message = "Environment must be one of: integration, test"
  }
}

variable "landlord_base_url" {
  description = "base URL for the landlord service"
  type        = string
}

variable "local_authority_base_url" {
  description = "base URL for the local authority service"
  type        = string
}
