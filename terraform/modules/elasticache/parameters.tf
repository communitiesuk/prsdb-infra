resource "aws_ssm_parameter" "redis_url" {
  name  = "${var.environment_name}-prsdb-redis-url"
  type  = "String"
  value = aws_elasticache_replication_group.main.primary_endpoint_address
}

resource "aws_ssm_parameter" "redis_port" {
  name  = "${var.environment_name}-prsdb-redis-port"
  type  = "String"
  value = var.redis_port
}

# Published for the webapp ECS task definition (separate Terraform state) to read,
# so the System Operator dashboard can query ElastiCache metrics from CloudWatch.
# CloudWatch uses the per-node CacheClusterId dimension, so we expose a member node id.
resource "aws_ssm_parameter" "redis_cluster_id" {
  name  = "${var.environment_name}-prsdb-redis-cluster-id"
  type  = "String"
  value = sort(tolist(aws_elasticache_replication_group.main.member_clusters))[0]
}