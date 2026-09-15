resource "aws_cloudwatch_log_group" "nft_seed" {
  name              = "/ecs/${var.environment_name}-seed-data"
  retention_in_days = 365
}

resource "aws_ecs_task_definition" "nft_seed" {
  family                   = "prsdb-seed-data-${var.environment_name}"
  cpu                      = 4096
  memory                   = 16384
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.webapp_ecs_task_role_arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode([
    {
      name      = "nft-data-seeder"
      image     = var.image_name
      essential = false
      user      = "root"

      environment = concat(
        var.common_environment_variables,
        [
          {
            name  = "SPRING_PROFILES_ACTIVE"
            value = "default,web-server-deactivated,nft-data-seeder"
          },
          {
            name  = "EPC_CERTIFICATE_BASE_URL"
            value = var.epc_certificate_base_url
          },
          {
            name  = "NFT_SEED_SYSTEM_OPERATORS"
            value = "150"
          },
          {
            name  = "NFT_SEED_LOCAL_COUNCIL_USERS"
            value = "3000"
          },
          {
            name  = "NFT_SEED_LANDLORDS"
            value = "2820000"
          },
          {
            name  = "NFT_SEED_PROPERTIES"
            value = "4700000"
          },
          {
            name  = "NFT_SEED_BATCH_SIZE"
            value = "10000"
          },
          {
            name  = "NFT_SEED_RANDOM_SEED"
            value = "239"
          },
          {
            name  = "NFT_SEED_REFERENCE_DATE"
            value = "2026-02-13"
          },
          {
            name  = "NFT_SEED_GENERATED_ADDRESSES"
            value = "0"
          },
        ]
      )
      secrets = var.common_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.nft_seed.name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "seeder"
        }
      }
    },
    {
      name      = "nft-database-dump"
      image     = "public.ecr.aws/docker/library/postgres:17-alpine"
      essential = true
      dependsOn = [
        {
          containerName = "nft-data-seeder"
          condition     = "SUCCESS"
        }
      ]
      environment = [
        {
          name  = "PGHOST"
          value = split(":", split("/", var.database_url)[0])[0]
        },
        {
          name  = "PGPORT"
          value = "5432"
        },
        {
          name  = "PGDATABASE"
          value = "prsdb"
        },
        {
          name  = "PGUSER"
          value = var.database_username
        },
        {
          name  = "AWS_REGION"
          value = "eu-west-2"
        },
      ]
      secrets = [
        {
          name      = "PGPASSWORD"
          valueFrom = var.database_password_secret_arn
        },
      ]
      command = [
        "sh",
        "-c",
        "set -o pipefail && apk add --no-cache aws-cli >/dev/null && pg_dump --format=custom --no-owner --no-acl | aws s3 cp - s3://${aws_s3_bucket.nft_seed.bucket}/seed-data.dump",
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.nft_seed.name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "dump"
        }
      }
    },
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = {
    Type = "manual-seed-data-task"
  }
}
