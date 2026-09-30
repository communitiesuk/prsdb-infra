terraform {
  required_version = "~>1.9.1"
}

module "task" {
  source = "../../../modules/ecs_task"

  environment_name              = var.environment_name
  task_name                     = "prsdb-one-login-simulator"
  container_image               = "ghcr.io/govuk-one-login/simulator@sha256:0d5e62c1db1c400c4881be2270b3f08aeb55c72ca3d9eb9a6e5196becef6f5e5"
  container_port                = 3000
  container_user                = "node"
  task_cpu                      = 4096
  task_memory                   = 8192
  ecs_task_execution_role_arn   = var.ecs_task_execution_role_arn
  cloudwatch_log_retention_days = 60

  environment_variables = [
    { name = "INTERACTIVE_MODE", value = "true" },
    { name = "SIMULATOR_URL", value = "https://nft.lb.register-home-to-rent.test.communities.gov.uk" },
    { name = "CLIENT_ID", value = var.one_login_client_id },
    { name = "PUBLIC_KEY", value = var.one_login_public_key },
    { name = "PUBLIC_KEY_SOURCE", value = "STATIC" },
    { name = "TOKEN_AUTH_METHOD", value = "private_key_jwt" },
    { name = "ID_TOKEN_SIGNING_ALGORITHM", value = "ES256" },
    { name = "IDENTITY_VERIFICATION_SUPPORTED", value = "true" },
    { name = "CLIENT_LOCS", value = "P0,P2" },
    { name = "SCOPES", value = "openid" },
    { name = "CLAIMS", value = "https://vocab.account.gov.uk/v1/coreIdentityJWT,https://vocab.account.gov.uk/v1/address,https://vocab.account.gov.uk/v1/returnCode" },
    { name = "REDIRECT_URLS", value = "https://nft.register-home-to-rent.test.communities.gov.uk/login/oauth2/code/one-login" },
    { name = "POST_LOGOUT_REDIRECT_URLS", value = "https://nft.register-home-to-rent.test.communities.gov.uk/signout" },
  ]

  tags = {
    Type = "one-login-simulator"
  }
}
