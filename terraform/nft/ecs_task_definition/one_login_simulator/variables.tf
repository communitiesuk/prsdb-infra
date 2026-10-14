variable "environment_name" {
  description = "must be one of: integration, test, nft, or production"
  type        = string
}

variable "image" {
  description = "Digest-pinned GOV.UK One Login Simulator image"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "The arn of the ecs task execution role"
  type        = string
}

variable "one_login_client_id" {
  description = "The One Login client ID the simulator presents to the webapp"
  type        = string
}

variable "one_login_public_key" {
  description = "The One Login public key the simulator uses to sign tokens"
  type        = string
  sensitive   = true
}
