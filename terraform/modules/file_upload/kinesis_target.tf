
resource "aws_cloudwatch_event_target" "store_scan_complete_event_target" {
  target_id = "store-scan-complete-event-target-${var.environment_name}"
  rule      = aws_cloudwatch_event_rule.scan_complete_event_rule.name
  arn       = aws_kinesis_firehose_delivery_stream.scan_complete_storage_stream.arn
}

resource "aws_kinesis_firehose_delivery_stream" "scan_complete_storage_stream" {
  name        = "scan-complete-storage-stream-${var.environment_name}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.kinesis_firehose_role.arn
    bucket_arn          = module.scan_result_event_bucket.bucket_arn
    buffering_size      = 1
    buffering_interval  = 10
    prefix              = "scan-complete-events/"
    error_output_prefix = "error/"
    file_extension      = ".json"
  }
}

resource "aws_iam_role" "kinesis_firehose_role" {
  name = "save-events-kinesis-firehose-role-${var.environment_name}"

  assume_role_policy = data.aws_iam_policy_document.kinesis_firehose_role.json
}

data "aws_iam_policy_document" "kinesis_firehose_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
