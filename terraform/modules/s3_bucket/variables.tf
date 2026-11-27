variable "bucket_name" {
  type        = string
  description = "The name of the bucket to create"
}

variable "access_log_bucket_name" {
  type        = string
  description = "The name of the accompanying log bucket"
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "Optional. KMS key to encrypt bucket and access logs bucket."
}

variable "force_destroy" {
  description = "Allow the buckets to be destroyed by Terraform even if they are not empty."
  type        = bool
  default     = false
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "Set to null to skip the general noncurrent-version lifecycle rule"
  default     = 180
}

variable "prefix_expiration_rules" {
  type = list(object({
    id              = string
    prefix          = string
    expiration_days = number
  }))
  default     = []
  description = "Optional object expiration rules scoped to explicit S3 key prefixes."

  validation {
    condition = (
      length(distinct([for rule in var.prefix_expiration_rules : rule.id])) == length(var.prefix_expiration_rules) &&
      alltrue([
        for rule in var.prefix_expiration_rules :
        can(regex("^[A-Za-z0-9][A-Za-z0-9-]*$", rule.id)) &&
        rule.id != "expire-old-versions" &&
        length(rule.id) <= 255 &&
        trimspace(rule.prefix) != "" &&
        rule.expiration_days >= 1 &&
        floor(rule.expiration_days) == rule.expiration_days
      ])
    )
    error_message = "Prefix lifecycle rules require unique alphanumeric IDs other than expire-old-versions, IDs no longer than 255 characters, non-empty prefixes, and positive whole retention days."
  }
}

variable "access_s3_log_expiration_days" {
  type        = number
  description = "The number of days to retain s3 access logs"
}

variable "policy" {
  description = "optional policy json to append to default bucket enforce ssl policy"
  type        = string
  default     = null
}

variable "object_lock_enabled" {
  description = "Whether the bucket is configured to allow AWS Object Lock"
  type        = bool
  default     = false
}

variable "eventbridge_notifications_enabled" {
  description = "Whether to send the bucket's object events to Amazon EventBridge, which AWS Backup continuous backups require"
  type        = bool
  default     = false
}