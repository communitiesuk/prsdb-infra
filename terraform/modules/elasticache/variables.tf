variable "environment_name" {
  description = "must be one of: integration, test, nft, or production"
  type        = string
  validation {
    condition     = contains(["integration", "test", "nft", "production"], var.environment_name)
    error_message = "Environment must be one of: integration, test"
  }
}

variable "redis_password" {
  description = "Password for the Valkey user"
  type        = string
  sensitive   = true
}

variable "redis_subnet_ids" {
  type        = list(string)
  description = "IDs of the isolated subnets for the serverless cache endpoint."
}

variable "snapshot_retention_limit" {
  type        = number
  description = "The number of days automatic serverless cache snapshots are retained before being deleted. If 0 then backups are turned off"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC to be associated with"
}
