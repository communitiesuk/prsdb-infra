# NFT performance restore task, worker role, log group, and narrowly scoped orchestration access.

data "aws_caller_identity" "current" {}

locals {
  nft_restore_task_family              = "prsdb-nft-vpc-restore-performance"
  nft_restore_dump_version             = ".pGtD.bGGLEZEER1T3UHCKDVryr_gpFU"
  nft_restore_certificate_key          = "seeding/certificate_template.png"
  nft_restore_certificate_version      = "Slbxit8aPt6zL27XiKXCsUQGWx.vRNnO"
  nft_restore_certificate_dump_version = ".pGtD.bGGLEZEER1T3UHCKDVryr_gpFU"
  nft_restore_certificate_dump_bytes   = "1063214910"
  nft_restore_certificate_dump_sha256  = "e0b6239d8d0be5a6b35209b34756e436073bd9392bbce2bee26c44ddfede88b0" # pragma: allowlist secret
  nft_restore_db_host                  = split(":", split("/", var.database_url)[0])[0]
  nft_restore_db_port                  = split(":", split("/", var.database_url)[0])[1]
  nft_restore_db_name                  = split("/", var.database_url)[1]
}

module "nft_restore_log_group" {
  source = "../../../modules/encrypted_log_group"

  log_group_name     = "/ecs/${var.environment_name}-seed-data-restore"
  log_retention_days = 365
}

moved {
  from = aws_cloudwatch_log_group.nft_restore
  to   = module.nft_restore_log_group.aws_cloudwatch_log_group.main
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
    actions   = ["s3:GetObjectVersion"]
    resources = ["${module.nft_seed_bucket.bucket_arn}/seed-data.dump"]

    condition {
      test     = "StringEquals"
      variable = "s3:VersionId"
      values   = [local.nft_restore_dump_version]
    }
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

  statement {
    actions = ["ecs:DescribeServices"]
    resources = [
      "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:service/${var.environment_name}-app/${var.environment_name}-app",
      "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:service/${var.environment_name}-app/${var.environment_name}-one-login-simulator",
      "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:service/${var.environment_name}-app/${var.environment_name}-async-worker",
    ]
  }

  statement {
    actions   = ["ecs:ListTasks"]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = ["arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:cluster/${var.environment_name}-scheduled-tasks"]
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

data "aws_iam_policy_document" "nft_restore_task_execution_log_group_kms" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = [module.nft_restore_log_group.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["logs.eu-west-2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "nft_restore_task_execution_log_group_kms" {
  name   = "${var.environment_name}-seed-data-restore-log-group-kms"
  role   = var.ecs_task_execution_role_name
  policy = data.aws_iam_policy_document.nft_restore_task_execution_log_group_kms.json
}

resource "aws_ecs_task_definition" "nft_restore" {
  family                   = local.nft_restore_task_family
  cpu                      = 4096
  memory                   = 16384
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = aws_iam_role.nft_restore_task.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  ephemeral_storage {
    size_in_gib = 21
  }

  container_definitions = jsonencode([
    {
      name      = "nft-vpc-restore"
      image     = "public.ecr.aws/docker/library/postgres:${var.postgres_major_version}-alpine"
      essential = true
      entryPoint = [
        "/bin/sh",
        "-c",
      ]
      command = [file("${path.module}/performance_test_restore.sh")]
      environment = [
        { name = "AWS_REGION", value = "eu-west-2" },
        { name = "AWS_DEFAULT_REGION", value = "eu-west-2" },
        { name = "AWS_PAGER", value = "" },
        { name = "AWS_MAX_ATTEMPTS", value = "3" },
        { name = "AWS_CLI_CONNECT_TIMEOUT", value = "10" },
        { name = "AWS_CLI_READ_TIMEOUT", value = "60" },
        { name = "EXPECTED_AWS_ACCOUNT", value = data.aws_caller_identity.current.account_id },
        { name = "NFT_DUMP_BUCKET", value = module.nft_seed_bucket.bucket },
        { name = "NFT_DUMP_KEY", value = "seed-data.dump" },
        { name = "NFT_DUMP_VERSION", value = local.nft_restore_dump_version },
        { name = "NFT_DUMP_BYTES", value = "1063214910" },
        { name = "NFT_DUMP_SHA256", value = "e0b6239d8d0be5a6b35209b34756e436073bd9392bbce2bee26c44ddfede88b0" }, # pragma: allowlist secret
        { name = "NFT_CERTIFICATE_KEY", value = local.nft_restore_certificate_key },
        { name = "NFT_CERTIFICATE_VERSION", value = local.nft_restore_certificate_version },
        { name = "NFT_CERTIFICATE_DUMP_VERSION", value = local.nft_restore_certificate_dump_version },
        { name = "NFT_CERTIFICATE_DUMP_BYTES", value = local.nft_restore_certificate_dump_bytes },
        { name = "NFT_CERTIFICATE_DUMP_SHA256", value = local.nft_restore_certificate_dump_sha256 },
        { name = "NFT_RESTORE_TASK_FAMILY", value = local.nft_restore_task_family },
        { name = "NFT_APP_CLUSTER", value = "${var.environment_name}-app" },
        { name = "NFT_APP_SERVICE", value = "${var.environment_name}-app" },
        { name = "NFT_SIMULATOR_SERVICE", value = "${var.environment_name}-one-login-simulator" },
        { name = "NFT_ASYNC_WORKER_SERVICE", value = "${var.environment_name}-async-worker" },
        { name = "NFT_SCHEDULED_CLUSTER", value = "${var.environment_name}-scheduled-tasks" },
        { name = "POSTGRES_MAJOR_VERSION", value = var.postgres_major_version },
        { name = "PGHOST", value = local.nft_restore_db_host },
        { name = "EXPECTED_PGHOST", value = local.nft_restore_db_host },
        { name = "PGPORT", value = local.nft_restore_db_port },
        { name = "PGDATABASE", value = local.nft_restore_db_name },
        { name = "PGUSER", value = var.database_username },
        { name = "PGSSLMODE", value = "require" },
        { name = "PGCONNECT_TIMEOUT", value = "10" },
        { name = "PGOPTIONS", value = "-c default_transaction_read_only=on -c statement_timeout=15000 -c idle_in_transaction_session_timeout=15000" },
      ]
      secrets = [
        {
          name      = "PGPASSWORD"
          valueFrom = var.database_password_secret_arn
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = module.nft_restore_log_group.name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "restore"
        }
      }
    },
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = {
    Type = "performance-test-restore-task"
  }
}

data "aws_iam_role" "performance_test_orchestrator" {
  name = "${var.environment_name}-performance-test-orchestrator-access"
}

data "aws_iam_policy_document" "performance_recovery_checkpoints" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${module.nft_seed_bucket.bucket_arn}/performance-recovery/*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [module.nft_seed_bucket.bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["performance-recovery/*"]
    }
  }

  # With Bucket Keys disabled S3 uses the object ARN; when enabled it uses the bucket ARN.
  statement {
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.nft_seed.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.eu-west-2.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = ["${module.nft_seed_bucket.bucket_arn}/performance-recovery/*"]
    }
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.nft_seed.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.eu-west-2.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = [module.nft_seed_bucket.bucket_arn]
    }
  }
}

resource "aws_iam_role_policy" "performance_recovery_checkpoints" {
  name   = "performance-recovery-checkpoints"
  role   = data.aws_iam_role.performance_test_orchestrator.name
  policy = data.aws_iam_policy_document.performance_recovery_checkpoints.json
}

data "aws_iam_policy_document" "performance_test_restore_orchestrator" {
  statement {
    actions   = ["s3:GetObjectVersion"]
    resources = ["arn:aws:s3:::prsdb-uploaded-files-${var.environment_name}/${local.nft_restore_certificate_key}"]

    condition {
      test     = "StringEquals"
      variable = "s3:VersionId"
      values   = [local.nft_restore_certificate_version]
    }
  }

  # ListSchedules does not support resource-level authorization; constrain this read to NFT's region.
  statement {
    actions   = ["scheduler:ListSchedules"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-west-2"]
    }
  }

  statement {
    actions = [
      "scheduler:GetSchedule",
      "scheduler:UpdateSchedule",
    ]
    resources = [
      for task_name in var.scheduled_task_names :
      "arn:aws:scheduler:eu-west-2:${data.aws_caller_identity.current.account_id}:schedule/${var.environment_name}-scheduled-tasks-group/${var.environment_name}-${task_name}-scheduled-task"
    ]
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nft-scheduled-tasks"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["scheduler.amazonaws.com"]
    }
  }

  statement {
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:task-definition/prsdb-async-worker-nft-performance-*:*"]
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nft-async-worker-ecs-task"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/nft-prsdb-scan-result-queue-name"]
  }

  statement {
    actions   = ["sqs:GetQueueAttributes"]
    resources = ["arn:aws:sqs:eu-west-2:${data.aws_caller_identity.current.account_id}:nft-prsdb-scan-result-queue"]
  }

  statement {
    actions   = ["ecs:ListServices"]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = ["arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:cluster/nft-app"]
    }
  }

  statement {
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
    ]
    resources = [
      "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:service/${var.environment_name}-app/${var.environment_name}-async-worker",
    ]
  }

  statement {
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.nft_restore.arn]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = ["arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:cluster/${var.environment_name}-app"]
    }
  }

  statement {
    actions = [
      "ecs:DescribeTasks",
      "ecs:StopTask",
    ]
    resources = [
      "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:task/${var.environment_name}-app/*",
    ]
  }

  statement {
    actions   = ["ecs:ListTasks"]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values = [
        "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:cluster/${var.environment_name}-app",
        "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:cluster/${var.environment_name}-scheduled-tasks",
      ]
    }
  }

  statement {
    actions = [
      "ecs:ListTaskDefinitions",
      "elasticloadbalancing:DescribeTargetHealth",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-west-2"]
    }
  }

  statement {
    actions   = ["logs:DescribeLogStreams"]
    resources = ["${module.nft_restore_log_group.log_group_arn}:*"]
  }

  statement {
    actions   = ["logs:GetLogEvents"]
    resources = ["${module.nft_restore_log_group.log_group_arn}:log-stream:restore/*"]
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.nft_restore_task.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "performance_test_restore_orchestrator" {
  name   = "${var.environment_name}-performance-test-vpc-restore"
  policy = data.aws_iam_policy_document.performance_test_restore_orchestrator.json
}

resource "aws_iam_role_policy_attachment" "performance_test_restore_orchestrator" {
  role       = data.aws_iam_role.performance_test_orchestrator.name
  policy_arn = aws_iam_policy.performance_test_restore_orchestrator.arn
}
