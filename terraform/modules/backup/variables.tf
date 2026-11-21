variable "environment_name" {
  description = "must be one of: integration, test, nft, or production"
  type        = string
  validation {
    condition     = contains(["integration", "test", "nft", "production"], var.environment_name)
    error_message = "Environment must be one of: integration, test, nft, or production"
  }
}

variable "s3_bucket_arns" {
  description = "ARNs of the S3 buckets to back up. Each bucket must have versioning and EventBridge notifications enabled"
  type        = list(string)
}

variable "backup_retention_days" {
  description = "Number of days to keep point in time recovery backups, daily snapshots and their cross-region copies"
  type        = number
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days, the maximum for continuous backups"
  }
}

variable "point_in_time_recovery_enabled" {
  description = "Whether to take continuous backups of the S3 buckets for point in time recovery. Turning this off keeps existing recovery points until they expire"
  type        = bool
}

variable "non_critical_alarm_sns_topic_arn" {
  description = "ARN of the SNS topic that non-critical backup failure alarms notify, or null while the environment's monitoring has not been created"
  type        = string
  default     = null
}
