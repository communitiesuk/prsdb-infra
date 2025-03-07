variable "environment_name" {
  description = "must be one of: integration, test"
  type        = string
  validation {
    condition     = contains(["integration", "test"], var.environment_name)
    error_message = "Environment must be one of: integration, test"
  }
}

variable "main_vpc_id" {
  type        = string
  description = "The id of the VPC."
}

variable "bastion_subnet_id" {
  type        = string
  description = "The private subnet into which to deploy the bastion"
}