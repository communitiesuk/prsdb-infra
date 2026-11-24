variable "environment_name" {
  description = "must be one of: integration, test, nft, or production"
  type        = string
  validation {
    condition     = contains(["integration", "test", "nft", "production"], var.environment_name)
    error_message = "Environment must be one of: integration, test, nft, or production"
  }
}

variable "critical_alarm_email_address" {
  description = "Email address to receive critical CloudWatch alarm notifications"
  type        = string
}

variable "non_critical_alarm_email_address" {
  description = "Email address to receive non-critical CloudWatch alarm notifications"
  type        = string
}

variable "cloudwatch_log_expiration_days" {
  type        = number
  description = "Number of days to retain cloudwatch logs for"
}

variable "ecs_cluster_name" {
  description = "Name of ECS cluster to create alarms for"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of ECS service to create alarms for"
  type        = string
}

variable "database_identifier" {
  description = "Identifier of DB instance to create alarms for"
  type        = string
}

variable "database_allocated_storage" {
  description = "Allocated storage of RDS instance to create alarms for"
  type        = number
}

variable "backup_replication_kms_key_arn" {
  description = "ARN of the KMS key encrypting cross-region replicated RDS automated backups"
  type        = string
}

variable "elasticache_cluster_ids" {
  description = "IDs of ElastiCache clusters to create alarms for"
  type        = set(string)
}

variable "alb_name" {
  description = "Name of ALB to create alarms for"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of ALB to create alarms for"
  type        = string
}

variable "alb_target_group_arn_suffix" {
  description = "ARN suffix of target group of ALB to create alarms for"
  type        = string
}

variable "webapp_ecs_task_role_name" {
  description = "Name of the webapp ECS task role to grant monitoring permissions to"
  type        = string
}

variable "enable_kms_cloudtrail_events" {
  type        = bool
  description = "Whether to log KMS  events to CloudTrail"
  default     = true
}

variable "backup_vault_kms_key_arns" {
  description = "ARNs of the KMS keys encrypting the AWS Backup vaults, to alarm when they are disabled or scheduled for deletion"
  type        = list(string)
}

variable "backup_role_arn" {
  description = "ARN of the AWS Backup role, whose own changes to the backed-up buckets' notification settings are expected"
  type        = string
}

variable "backed_up_s3_bucket_names" {
  description = "Names of the S3 buckets backed up by AWS Backup, to alarm when their notification settings change"
  type        = list(string)
}
