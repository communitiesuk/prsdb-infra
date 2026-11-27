resource "aws_ssm_parameter" "redis_url" {
  name  = "${var.environment_name}-prsdb-redis-url"
  type  = "String"
  value = aws_elasticache_serverless_cache.main.endpoint[0].address
}

resource "aws_ssm_parameter" "redis_port" {
  name  = "${var.environment_name}-prsdb-redis-port"
  type  = "String"
  value = aws_elasticache_serverless_cache.main.endpoint[0].port
}

# Published for the webapp ECS task definition (separate Terraform state) to read,
# so the System Operator dashboard can query ElastiCache metrics from CloudWatch.
resource "aws_ssm_parameter" "redis_cluster_id" {
  name  = "${var.environment_name}-prsdb-redis-cluster-id"
  type  = "String"
  value = aws_elasticache_serverless_cache.main.name
}

resource "aws_ssm_parameter" "redis_username" {
  name  = "${var.environment_name}-prsdb-redis-username"
  type  = "String"
  value = aws_elasticache_user.webapp.user_name
}