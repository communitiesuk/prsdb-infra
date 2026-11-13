resource "aws_ssm_parameter" "quarantine_bucket" {
  name  = "${var.environment_name}-prsdb-quarantine-bucket"
  type  = "String"
  value = module.quarantine_bucket.bucket
}

resource "aws_ssm_parameter" "uploaded_file_bucket" {
  name  = "${var.environment_name}-prsdb-uploaded-files"
  type  = "String"
  value = module.uploaded_files_bucket.bucket
}

resource "aws_ssm_parameter" "scan_result_queue_name" {
  name  = "${var.environment_name}-prsdb-scan-result-queue-name"
  type  = "String"
  value = aws_sqs_queue.scan_result_queue.name
}
