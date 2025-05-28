output "rds_security_group_id" {
  value       = aws_security_group.main.id
  description = "The id of the rds security group"
}
