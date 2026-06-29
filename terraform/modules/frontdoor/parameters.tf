# Published for the webapp ECS task definition (separate Terraform state) to read,
# so the System Operator dashboard can query CloudFront metrics from CloudWatch.
resource "aws_ssm_parameter" "cloudfront_distribution_id" {
  name  = "${var.environment_name}-prsdb-cloudfront-distribution-id"
  type  = "String"
  value = aws_cloudfront_distribution.main.id
}
