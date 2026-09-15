data "aws_iam_policy_document" "nft_seed_task_s3" {
  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.nft_seed.arn}/*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.nft_seed.arn]
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
    resources = ["${aws_s3_bucket.nft_seed.arn}/*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.nft_seed.arn]
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
      "ecs:DescribeServices",
      "ecs:StopTask",
    ]
    resources = ["*"]
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

resource "aws_iam_role_policy_attachment" "nft_seed_run_task" {
  role       = data.aws_iam_role.github_actions_rds_access.name
  policy_arn = aws_iam_policy.nft_seed_run_task.arn
}
