# Resource - specific parameters are to be created in their respective modules

resource "aws_ssm_parameter" "one_login_public_key" {
  name  = "${var.environment_name}-one-login-public-key"
  type  = "String"
  value = "default" # To be set manually on AWS

  lifecycle {
    ignore_changes = ["value"]
  }
}

resource "aws_ssm_parameter" "one_login_client_id" {
  name  = "${var.environment_name}-one-login-client-id"
  type  = "String"
  value = "default" # To be set manually on AWS

  lifecycle {
    ignore_changes = ["value"]
  }
}

resource "aws_ssm_parameter" "one_login_issuer_url" {
  name  = "${var.environment_name}-one-login-issuer-url"
  type  = "String"
  value = "default" # To be set manually on AWS

  lifecycle {
    ignore_changes = ["value"]
  }
}