output "redis_security_group_id" {
  value       = aws_security_group.redis.id
  description = "ID for the security group for redis"
}

output "serverless_cache_name" {
  value       = aws_elasticache_serverless_cache.main.name
  description = "Name of the Valkey Serverless cache, used for CloudWatch dimensions"
}