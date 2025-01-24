output "database_password" {
  description = "Randomly generated password for database"
  value       = random_password.database_password
  sensitive   = true
}