
output "security_group_id" {
  description = "Id of the bastion security group"
  value       = aws_security_group.bastion.id
}