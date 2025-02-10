output "database_password" {
  description = "Randomly generated password for database"
  value       = random_password.database_password
  sensitive   = true
}

output "redis_password" {
  description = "Randomly generated password for Redis"
  value       = random_password.redis_password
  sensitive   = true
}