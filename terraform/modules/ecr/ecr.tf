#tfsec:ignore:aws-ecr-repository-customer-key:encryption using KMS CMK not required
resource "aws_ecr_repository" "main" {
  name                 = "${var.environment_name}-webapp"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last var.image_retention_count images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.image_retention_count
      }
    }]
  })
}

resource "aws_ecr_repository" "one_login_simulator" {
  count = var.create_simulator_repository ? 1 : 0

  name                 = "${var.environment_name}-one-login-simulator"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "one_login_simulator" {
  count = var.create_simulator_repository ? 1 : 0

  repository = aws_ecr_repository.one_login_simulator[0].name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 3 simulator images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
    }]
  })
}