mock_provider "aws" {}

variables {
  bucket_name                   = "test-data-bucket"
  access_log_bucket_name        = "test-data-access-logs"
  access_s3_log_expiration_days = 700
}

run "defaults_to_general_lifecycle_rule" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.main) == 1
    error_message = "The default general lifecycle rule should create a lifecycle configuration."
  }

  assert {
    condition = (
      one(aws_s3_bucket_lifecycle_configuration.main[0].rule).id == "expire-old-versions" &&
      one(aws_s3_bucket_lifecycle_configuration.main[0].rule).noncurrent_version_expiration[0].noncurrent_days == 180
    )
    error_message = "The default lifecycle rule should retain noncurrent versions for 180 days."
  }
}

run "supports_multiple_prefix_rules" {
  command = plan

  variables {
    prefix_expiration_rules = [
      {
        id              = "expire-checkpoints"
        prefix          = "checkpoints/"
        expiration_days = 7
      },
      {
        id              = "expire-exports"
        prefix          = "exports/"
        expiration_days = 30
      },
    ]
  }

  assert {
    condition = {
      for rule in aws_s3_bucket_lifecycle_configuration.main[0].rule :
      rule.id => {
        prefix          = rule.filter[0].prefix
        current_days    = rule.expiration[0].days
        noncurrent_days = rule.noncurrent_version_expiration[0].noncurrent_days
      } if rule.id != "expire-old-versions"
      } == {
      "expire-checkpoints" = {
        prefix          = "checkpoints/"
        current_days    = 7
        noncurrent_days = 7
      }
      "expire-exports" = {
        prefix          = "exports/"
        current_days    = 30
        noncurrent_days = 30
      }
    }
    error_message = "Each prefix rule should retain its exact prefix and current/noncurrent expiry days."
  }
}

run "supports_prefix_rules_without_general_retention" {
  command = plan

  variables {
    noncurrent_version_expiration_days = null
    prefix_expiration_rules = [{
      id              = "expire-checkpoints"
      prefix          = "checkpoints/"
      expiration_days = 7
    }]
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.main) == 1
    error_message = "Prefix rules should create lifecycle configuration when general retention is disabled."
  }

  assert {
    condition = (
      one(aws_s3_bucket_lifecycle_configuration.main[0].rule).filter[0].prefix == "checkpoints/" &&
      one(aws_s3_bucket_lifecycle_configuration.main[0].rule).expiration[0].days == 7 &&
      one(aws_s3_bucket_lifecycle_configuration.main[0].rule).noncurrent_version_expiration[0].noncurrent_days == 7
    )
    error_message = "A prefix-only lifecycle rule should retain its prefix and both expiry settings."
  }
}

run "omits_lifecycle_configuration_when_all_rules_are_disabled" {
  command = plan

  variables {
    noncurrent_version_expiration_days = null
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.main) == 0
    error_message = "No lifecycle configuration should be created when general and prefix rules are disabled."
  }
}

run "rejects_duplicate_prefix_rule_ids" {
  command = plan

  variables {
    prefix_expiration_rules = [
      {
        id              = "expire-checkpoints"
        prefix          = "checkpoints/"
        expiration_days = 7
      },
      {
        id              = "expire-checkpoints"
        prefix          = "archives/"
        expiration_days = 30
      },
    ]
  }

  expect_failures = [var.prefix_expiration_rules]
}

run "rejects_reserved_general_rule_id" {
  command = plan

  variables {
    prefix_expiration_rules = [{
      id              = "expire-old-versions"
      prefix          = "checkpoints/"
      expiration_days = 7
    }]
  }

  expect_failures = [var.prefix_expiration_rules]
}

run "rejects_invalid_prefix_rule_id" {
  command = plan

  variables {
    prefix_expiration_rules = [{
      id              = "-invalid-id"
      prefix          = "checkpoints/"
      expiration_days = 7
    }]
  }

  expect_failures = [var.prefix_expiration_rules]
}

run "rejects_prefix_rule_id_longer_than_255_characters" {
  command = plan

  variables {
    prefix_expiration_rules = [{
      id              = join("", [for index in range(256) : "a"])
      prefix          = "checkpoints/"
      expiration_days = 7
    }]
  }

  expect_failures = [var.prefix_expiration_rules]
}

run "rejects_zero_retention_days" {
  command = plan

  variables {
    prefix_expiration_rules = [{
      id              = "expire-checkpoints"
      prefix          = "checkpoints/"
      expiration_days = 0
    }]
  }

  expect_failures = [var.prefix_expiration_rules]
}

run "rejects_fractional_retention_days" {
  command = plan

  variables {
    prefix_expiration_rules = [{
      id              = "expire-checkpoints"
      prefix          = "checkpoints/"
      expiration_days = 1.5
    }]
  }

  expect_failures = [var.prefix_expiration_rules]
}

run "rejects_empty_prefix" {
  command = plan

  variables {
    prefix_expiration_rules = [{
      id              = "expire-checkpoints"
      prefix          = ""
      expiration_days = 7
    }]
  }

  expect_failures = [var.prefix_expiration_rules]
}
