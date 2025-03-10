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

variable "vpc_cidr_block" {
  type        = string
  description = "A collection of IP addresses to be allocated to VPC."
}

variable "bastion_subnet_ids" {
  type        = list(string)
  description = "The private subnets into which to deploy a bastion"
}