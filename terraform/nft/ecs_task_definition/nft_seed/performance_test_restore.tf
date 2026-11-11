# NFT performance restore task, worker role, log group, and narrowly scoped orchestration access.

data "aws_caller_identity" "current" {}

locals {
  nft_restore_task_family  = "prsdb-nft-vpc-restore-performance"
  nft_restore_dump_version = "PE8_its41c5Rhu_CBd7CVmm1qan.lZF7"
  nft_restore_db_host      = split(":", split("/", var.database_url)[0])[0]
  nft_restore_db_port      = split(":", split("/", var.database_url)[0])[1]
  nft_restore_db_name      = split("/", var.database_url)[1]
}

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
      image     = "docker.io/library/postgres@sha256:cbf42f0edc946c0bc1b8eeed62403734e1f25dc67a3491455d07a92fdb558b28"
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
        { name = "NFT_DUMP_BYTES", value = "940283583" },
        { name = "NFT_DUMP_SHA256", value = "71cae9caa5d84e4485c8f327ecfe169b8fbfa52d4ca85e359cb81dd5fae1251c" }, # pragma: allowlist secret
        { name = "NFT_RESTORE_TASK_FAMILY", value = local.nft_restore_task_family },
        { name = "NFT_APP_CLUSTER", value = "${var.environment_name}-app" },
        { name = "NFT_APP_SERVICE", value = "${var.environment_name}-app" },
        { name = "NFT_SIMULATOR_SERVICE", value = "${var.environment_name}-one-login-simulator" },
        { name = "NFT_ASYNC_WORKER_SERVICE", value = "${var.environment_name}-async-worker" },
        { name = "NFT_SCHEDULED_CLUSTER", value = "${var.environment_name}-scheduled-tasks" },
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
          awslogs-group         = aws_cloudwatch_log_group.nft_restore.name
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

data "aws_iam_policy_document" "performance_test_restore_orchestrator" {
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
    resources = ["${aws_cloudwatch_log_group.nft_restore.arn}:*"]
  }

  statement {
    actions   = ["logs:GetLogEvents"]
    resources = ["${aws_cloudwatch_log_group.nft_restore.arn}:log-stream:restore/*"]
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
