variable "ssl_certs_created" {
  description = "Indicates whether ssl certificates have already been manually created"
  type        = bool
  default     = true
}

variable "task_definition_created" {
  description = "Indicates whether the initial task definition has been created"
  type        = bool
  default     = true
}

variable "regional_deadlines" {
  description = "Registration deadline dates by region, in YYYY-MM-DD format"
  type        = map(string)
  default = {
    west_midlands        = "2027-03-14"
    east_of_england      = "2027-04-14"
    east_midlands        = "2027-05-14"
    south_east           = "2027-06-14"
    yorkshire_and_humber = "2027-07-14"
    north_west           = "2027-08-14"
    north_east           = "2027-09-14"
    london               = "2027-10-14"
    south_west           = "2027-11-14"
  }
  validation {
    condition = alltrue([
      for date in values(var.regional_deadlines) :
      can(regex("^\\d{4}-\\d{2}-\\d{2}$", date)) && can(formatdate("YYYY-MM-DD", "${date}T00:00:00Z"))
    ])
    error_message = "Regional deadlines must be valid dates in YYYY-MM-DD format."
  }
}

variable "critical_alarm_email_address" {
  description = "Email address to receive critical CloudWatch alarm notifications"
  type        = string
  sensitive   = true
}

variable "non_critical_alarm_email_address" {
  description = "Email address to receive non-critical CloudWatch alarm notifications"
  type        = string
  sensitive   = true
}

variable "ip_restrictions_on" {
  description = "Enable IP restrictions for the web application"
  type        = bool
  default     = false
}

variable "maintenance_mode_on" {
  type        = bool
  description = "Indicates whether maintenance mode is on"
  default     = false
}

variable "enable_kms_cloudtrail_events" {
  type        = bool
  description = "Whether to log KMS  events to CloudTrail"
  default     = true
}
