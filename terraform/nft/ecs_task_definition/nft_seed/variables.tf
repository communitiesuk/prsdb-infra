# Manual, one-off task: generates the NFT performance-test seed dataset via
# NftDataSeeder, then pg_dumps it to S3. Run only when a schema migration
# changes seeded tables or a new performance-test baseline is deliberately
# required - it is not scheduled and is not run on every deploy. The dump
# this produces is the input for the (future) NFT database reset workflow.

variable "environment_name" {
  description = "must be one of: integration, test, nft, or production"
  type        = string
}

variable "image_name" {
  description = "name of the docker image to run for the seeder container"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "The arn of the ecs task execution role"
  type        = string
}

variable "webapp_ecs_task_role_arn" {
  description = "The arn of the webapp ecs task role"
  type        = string
}

variable "webapp_ecs_task_role_name" {
  description = "The name of the webapp ecs task role"
  type        = string
}

variable "common_environment_variables" {
  description = "The common (non-secret) environment variables shared with the webapp task definition"
  type = list(object({
    name  = string
    value = string
  }))
}

variable "common_secrets" {
  description = "The common secrets shared with the webapp task definition"
  type = list(object({
    name      = string
    valueFrom = string
  }))
}

variable "database_url" {
  description = "The RDS endpoint and database name, in the form <host>:<port>/<db_name>"
  type        = string
}

variable "database_username" {
  description = "The RDS master username"
  type        = string
}

variable "database_password_secret_arn" {
  description = "The arn of the secrets manager secret containing the RDS master password"
  type        = string
}
