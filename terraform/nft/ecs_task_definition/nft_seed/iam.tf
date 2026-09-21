data "aws_iam_policy_document" "nft_seed_task_s3" {
  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:PutObject",
    ]
    resources = ["${module.nft_seed_bucket.bucket_arn}/*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [module.nft_seed_bucket.bucket_arn]
  }

  statement {
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.nft_seed.arn]
  }
}

resource "aws_iam_policy" "nft_seed_task_s3" {
  name   = "${var.environment_name}-seed-data-task-s3"
  policy = data.aws_iam_policy_document.nft_seed_task_s3.json
}

resource "aws_iam_role_policy_attachment" "nft_seed_task_s3" {
  role       = var.webapp_ecs_task_role_name
  policy_arn = aws_iam_policy.nft_seed_task_s3.arn
}

# Grants read access to the dump for the (future) NFT database reset workflow.
data "aws_iam_policy_document" "nft_seed_restore" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.nft_seed_bucket.bucket_arn}/*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [module.nft_seed_bucket.bucket_arn]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.nft_seed.arn]
  }
}

resource "aws_iam_policy" "nft_seed_restore" {
  name   = "${var.environment_name}-seed-data-restore"
  policy = data.aws_iam_policy_document.nft_seed_restore.json
}

# Created in the github_actions_access module.
data "aws_iam_role" "github_actions_rds_access" {
  name = "${var.environment_name}-rds-access"
}

resource "aws_iam_role_policy_attachment" "nft_seed_restore" {
  role       = data.aws_iam_role.github_actions_rds_access.name
  policy_arn = aws_iam_policy.nft_seed_restore.arn
}

data "aws_iam_policy_document" "nft_seed_run_task" {
  statement {
    actions   = ["ecs:RunTask"]
    resources = ["arn:aws:ecs:eu-west-2:*:task-definition/prsdb-seed-data-${var.environment_name}:*"]
  }

  statement {
    actions = [
      "ecs:DescribeTasks",
      "ecs:StopTask",
    ]
    resources = ["arn:aws:ecs:eu-west-2:*:task/${var.environment_name}-app/*"]
  }

  statement {
    actions   = ["ecs:DescribeServices"]
    resources = ["arn:aws:ecs:eu-west-2:*:service/${var.environment_name}-app/${var.environment_name}-app"]
  }

  statement {
    actions = ["iam:PassRole"]
    resources = [
      var.ecs_task_execution_role_arn,
      var.webapp_ecs_task_role_arn,
    ]
  }
}

resource "aws_iam_policy" "nft_seed_run_task" {
  name   = "${var.environment_name}-seed-data-run-task"
  policy = data.aws_iam_policy_document.nft_seed_run_task.json
}

# Created in the github_actions_access module (terraform/<environment> root state).
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

# Dedicated role for the prsdb-infra repo's generate-nft-seed workflow: the existing
# `${environment_name}-rds-access` role is scoped to GitHub Actions in the prsdb-webapp repo, so it
# can't be assumed from here.
data "aws_iam_policy_document" "nft_seed_generate_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = "token.actions.githubusercontent.com:aud"
    }

    condition {
      test     = "StringLike"
      values   = ["repo:communitiesuk/prsdb-infra:*"]
      variable = "token.actions.githubusercontent.com:sub"
    }
  }
}

resource "aws_iam_role" "nft_seed_generate" {
  name                 = "${var.environment_name}-seed-data-generate"
  assume_role_policy   = data.aws_iam_policy_document.nft_seed_generate_assume_role.json
  max_session_duration = 21600 # 6 hours - the seed + dump run can take a while, see generate-nft-seed.yml
}

resource "aws_iam_role_policy_attachment" "nft_seed_run_task" {
  role       = aws_iam_role.nft_seed_generate.name
  policy_arn = aws_iam_policy.nft_seed_run_task.arn
}
