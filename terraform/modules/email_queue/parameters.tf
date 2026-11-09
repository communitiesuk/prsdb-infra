resource "aws_ssm_parameter" "email_queue_name" {
  name  = "${var.environment_name}-prsdb-email-queue-name"
  type  = "String"
  value = aws_sqs_queue.email_queue.name
}
