resource "aws_iam_role" "backup" {
  name               = "prsdb-AWSBackup-role-${var.environment_name}"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json
}

data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy" "backup" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = data.aws_iam_policy.backup.arn
}

data "aws_iam_policy" "restores" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_iam_role_policy_attachment" "restores" {
  role       = aws_iam_role.backup.name
  policy_arn = data.aws_iam_policy.restores.arn
}

data "aws_iam_policy" "s3_backup" {
  arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
}

resource "aws_iam_role_policy_attachment" "s3_backup" {
  role       = aws_iam_role.backup.name
  policy_arn = data.aws_iam_policy.s3_backup.arn
}

data "aws_iam_policy" "s3_restore" {
  arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore"
}

resource "aws_iam_role_policy_attachment" "s3_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = data.aws_iam_policy.s3_restore.arn
}

data "aws_iam_policy_document" "backup_vault_kms" {
  statement {
    sid = "UseBackupVaultKeys"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:DescribeKey",
    ]
    resources = local.backup_vault_kms_key_arns
  }

  statement {
    sid       = "GrantBackupVaultKeysToAwsResources"
    actions   = ["kms:CreateGrant"]
    resources = local.backup_vault_kms_key_arns

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "backup_vault_kms" {
  name   = "backup-vault-kms-${var.environment_name}"
  policy = data.aws_iam_policy_document.backup_vault_kms.json
}

resource "aws_iam_role_policy_attachment" "backup_vault_kms" {
  role       = aws_iam_role.backup.name
  policy_arn = aws_iam_policy.backup_vault_kms.arn
}
