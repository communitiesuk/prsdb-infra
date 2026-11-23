data "aws_iam_policy_document" "send_to_email_queue" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.email_queue.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [aws_kms_key.email_queue.arn]
  }
}

resource "aws_iam_policy" "send_to_email_queue" {
  name   = "${var.environment_name}-send-to-email-queue"
  policy = data.aws_iam_policy_document.send_to_email_queue.json
}

resource "aws_iam_role_policy_attachment" "webapp_send_to_email_queue" {
  role       = var.webapp_ecs_task_role_name
  policy_arn = aws_iam_policy.send_to_email_queue.arn
}

resource "aws_iam_role_policy_attachment" "async_worker_send_to_email_queue" {
  role       = var.async_worker_ecs_task_role_name
  policy_arn = aws_iam_policy.send_to_email_queue.arn
}

data "aws_iam_policy_document" "consume_email_queue" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.email_queue.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.email_queue.arn]
  }
}

resource "aws_iam_policy" "consume_email_queue" {
  name   = "${var.environment_name}-consume-email-queue"
  policy = data.aws_iam_policy_document.consume_email_queue.json
}

resource "aws_iam_role_policy_attachment" "async_worker_consume_email_queue" {
  role       = var.async_worker_ecs_task_role_name
  policy_arn = aws_iam_policy.consume_email_queue.arn
}
