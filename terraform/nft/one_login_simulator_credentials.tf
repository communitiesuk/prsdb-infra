# Dedicated One Login Simulator credentials (NFT-only)
#
# The simulator must never share client credentials with the real GOV.UK One Login integration, so it gets its
# own SSM parameters and secret here rather than reusing module.parameters / module.secrets (which are shared
# across all environments). The webapp's `one-login-simulator` Spring profile reads these same values via
# ONE_LOGIN_SIMULATOR_CLIENT_ID / ONE_LOGIN_SIMULATOR_PUBLIC_KEY / ONE_LOGIN_SIMULATOR_PRIVATE_KEY.

resource "aws_ssm_parameter" "one_login_simulator_client_id" {
  name  = "${local.environment_name}-one-login-simulator-client-id"
  type  = "String"
  value = "default_to_be_set_manually" # To be set manually on AWS

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "one_login_simulator_public_key" {
  name  = "${local.environment_name}-one-login-simulator-public-key"
  type  = "String"
  value = "default_to_be_set_manually" # To be set manually on AWS

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_secretsmanager_secret" "one_login_simulator_private_key" {
  name                    = "tf-${local.environment_name}-one-login-simulator-private-key"
  description             = "Private key the webapp uses to authenticate to the NFT One Login simulator (dedicated - not the real One Login private key)"
  recovery_window_in_days = 0
  kms_key_id              = module.secrets.secrets_kms_key_arn
}

resource "aws_iam_role_policy" "one_login_simulator_private_key_access" {
  name = "${local.environment_name}-one-login-simulator-private-key-access"
  role = module.ecr.ecs_task_execution_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["secretsmanager:GetSecretValue"]
        Effect   = "Allow"
        Resource = [aws_secretsmanager_secret.one_login_simulator_private_key.arn]
      }
    ]
  })
}
