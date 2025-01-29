resource "aws_security_group" "main" {
  name        = "${var.environment_name}-rds"
  description = "RDS security group"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}