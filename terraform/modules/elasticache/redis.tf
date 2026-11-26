resource "aws_elasticache_user" "webapp" {
  user_id       = "prsdb-${var.environment_name}-webapp"
  user_name     = "prsdb-${var.environment_name}-webapp"
  engine        = "valkey"
  access_string = "on ~* +@all"
  passwords     = [var.redis_password]
}

resource "aws_elasticache_user_group" "webapp" {
  user_group_id = "prsdb-${var.environment_name}-webapp"
  engine        = "valkey"
  user_ids      = [aws_elasticache_user.webapp.user_id]
}

resource "aws_elasticache_serverless_cache" "main" {
  name                     = "prsdb-cache-${var.environment_name}"
  engine                   = "valkey"
  connection_type          = "vpc"
  subnet_ids               = var.redis_subnet_ids
  security_group_ids       = [aws_security_group.redis.id]
  user_group_id            = aws_elasticache_user_group.webapp.user_group_id
  snapshot_retention_limit = var.snapshot_retention_limit
  daily_snapshot_time      = "02:30"
}
