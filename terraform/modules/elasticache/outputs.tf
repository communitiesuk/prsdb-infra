output "redis_security_group_id" {
  value       = aws_security_group.redis.id
  description = "ID for the security group for redis"
}