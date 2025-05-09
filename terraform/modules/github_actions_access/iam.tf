data "aws_caller_identity" "current" {}

# Read only role for terraform plan
resource "aws_iam_role" "github_actions_terraform_plan" {
  name               = "github-actions-terraform-ci-plan-read-only"
  assume_role_policy = data.aws_iam_policy_document.github_actions_terraform_plan_assume_role.json
}

data "aws_iam_policy_document" "github_actions_terraform_plan_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.main.arn]
    }

    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = "token.actions.githubusercontent.com:aud"
    }

    condition {
      test = "StringLike"
      values = [
        "repo:communitiesuk/prsdb-infra:*",
        "repo:communitiesuk/prsdb-webapp:*",
      ]
      variable = "token.actions.githubusercontent.com:sub"
    }
  }
}

data "aws_iam_policy" "terraform_state_read_only" {
  # Created in the terraform_backend module
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/tf-state-read-only"
}

resource "aws_iam_role_policy_attachment" "github_actions_terraform_plan_state_read" {
  role       = aws_iam_role.github_actions_terraform_plan.name
  policy_arn = data.aws_iam_policy.terraform_state_read_only.arn
}

data "aws_iam_policy" "read_only_access" {
  arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "github_actions_terraform_plan_read_only_access" {
  role       = aws_iam_role.github_actions_terraform_plan.name
  policy_arn = data.aws_iam_policy.read_only_access.arn
}


# Admin role for terraform apply
resource "aws_iam_role" "github_actions_terraform_admin" {
  name               = "github-actions-terraform-admin"
  assume_role_policy = data.aws_iam_policy_document.github_actions_terraform_admin_assume_role.json
}

data "aws_iam_policy_document" "github_actions_terraform_admin_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.main.arn]
    }

    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = "token.actions.githubusercontent.com:aud"
    }

    condition {
      test = "StringLike"
      values = [
        "repo:communitiesuk/prsdb-infra:*",
        "repo:communitiesuk/prsdb-webapp:*",
      ]
      variable = "token.actions.githubusercontent.com:sub"
    }
  }
}

data "aws_iam_policy" "administrator_access" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "github_actions_terraform_admin_access" {
  role       = aws_iam_role.github_actions_terraform_admin.name
  policy_arn = data.aws_iam_policy.administrator_access.arn
}

# ECR Push role for webapp repo
data "aws_iam_policy_document" "github_actions_push_ecr_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.main.arn]
    }

    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = "token.actions.githubusercontent.com:aud"
    }

    condition {
      test = "StringLike"
      values = [
        "repo:communitiesuk/prsdb-webapp:*",
      ]
      variable = "token.actions.githubusercontent.com:sub"
    }
  }
}

resource "aws_iam_role" "push_image" {
  name               = "${var.environment_name}-push-image"
  assume_role_policy = data.aws_iam_policy_document.github_actions_push_ecr_assume_role.json
}

resource "aws_iam_role_policy_attachment" "allow_push_image_policy_attachment" {
  role       = aws_iam_role.push_image.name
  policy_arn = var.push_ecr_image_policy_arn
}