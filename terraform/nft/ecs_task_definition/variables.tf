variable "image_name" {
  description = "name of the docker image to deploy"
  type        = string
  default     = "nginx:alpine"
}

variable "one_login_simulator_image_digest" {
  description = "Digest of the mirrored NFT GOV.UK One Login Simulator image"
  type        = string
  default     = "sha256:5257554c6f6a50c471ad231bc8f13da4a866b4a2e320a6d1f2f74e5d0ad52755"

  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.one_login_simulator_image_digest))
    error_message = "The One Login simulator image digest must use sha256 followed by 64 hexadecimal characters."
  }
}

variable "file_upload_buckets_created" {
  description = "Flag to indicate if the file upload buckets have been created"
  type        = bool
  default     = true
}