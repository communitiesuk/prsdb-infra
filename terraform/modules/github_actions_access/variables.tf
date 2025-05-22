variable "environment_name" {
  description = "must be one of: integration, test"
  type        = string
  validation {
    condition     = contains(["integration", "test"], var.environment_name)
    error_message = "Environment must be one of: integration, test"
  }
}

variable "push_ecr_image_policy_arn" {
  description = "arn of the iam policy for pushing images to ecr"
  type        = string
}

variable "rds_access_policy_arn" {
  description = "arn of the iam policy for rds access"
  type        = string
}
