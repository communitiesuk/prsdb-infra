# Published for the webapp ECS task definition (separate Terraform state) to read,
# so the System Operator dashboard can query ECS metrics from CloudWatch.
resource "aws_ssm_parameter" "ecs_cluster_name" {
  name  = "${var.environment_name}-prsdb-ecs-cluster-name"
  type  = "String"
  value = aws_ecs_cluster.main.name
}

resource "aws_ssm_parameter" "ecs_service_name" {
  name  = "${var.environment_name}-prsdb-ecs-service-name"
  type  = "String"
  value = aws_ecs_service.webapp.name
}
