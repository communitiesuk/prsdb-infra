output "log_group_arn" {
  value = aws_cloudwatch_log_group.main.arn
}

output "name" {
  value = aws_cloudwatch_log_group.main.name
}
