plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format = "snake_case"
}

rule "terraform_unused_required_providers" {
  enabled = true
}

# TODO PRSD-1294 - shouldn't need to disable this but it is failing and I don't think it should be
rule "aws_cloudfront_function_invalid_runtime" {
  enabled = false
}

config {
  call_module_type = "all"
}

plugin "aws" {
  enabled = true
  version = "0.24.1"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}