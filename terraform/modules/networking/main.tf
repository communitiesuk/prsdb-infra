data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_security_group" "aws_service_vpc_endpoints" {
  name        = "vpc-endpoints-${var.environment_name}"
  description = "VPC Endpoint security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Connections from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
}