# Task role and log group for the in-VPC restore task that loads the seed dump into the NFT database.
# The role can read only the dump (and decrypt it) and write its own logs; it has no other AWS access.

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "nft_restore" {
  name              = "/ecs/${var.environment_name}-seed-data-restore"
  retention_in_days = 365
}

data "aws_iam_policy_document" "nft_restore_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

data "aws_iam_policy_document" "nft_restore_task" {
  statement {
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${module.nft_seed_bucket.bucket_arn}/seed-data.dump"]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.nft_seed.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.eu-west-2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nft_restore_task" {
  name               = "${var.environment_name}-seed-data-restore-task"
  assume_role_policy = data.aws_iam_policy_document.nft_restore_assume_role.json
}

resource "aws_iam_role_policy" "nft_restore_task" {
  name   = "read-seed-dump"
  role   = aws_iam_role.nft_restore_task.id
  policy = data.aws_iam_policy_document.nft_restore_task.json
}
