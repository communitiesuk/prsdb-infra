variable "image_name" {
  description = "name of the docker image to deploy"
  type        = string
  default     = "nginx:alpine"
}

variable "one_login_simulator_image" {
  description = "Digest-pinned GOV.UK One Login Simulator image"
  type        = string
  default     = "ghcr.io/govuk-one-login/simulator@sha256:0d5e62c1db1c400c4881be2270b3f08aeb55c72ca3d9eb9a6e5196becef6f5e5"

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.one_login_simulator_image))
    error_message = "The One Login simulator image must use a sha256 digest."
  }
}

variable "file_upload_buckets_created" {
  description = "Flag to indicate if the file upload buckets have been created"
  type        = bool
  default     = true
}