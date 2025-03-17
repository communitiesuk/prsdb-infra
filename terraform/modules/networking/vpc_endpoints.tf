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

locals {
  vpc_endpoint_services = [
    "ssm",
    "ssmmessages",
    "ec2messages",
    "secretsmanager",
    "ecr.api",
    "ecr.dkr",
    "ecs",
    "ecs-agent",
    "ecs-telemetry",
    "kms",
    "ec2",
    "monitoring",
    "logs"
  ]
}

data "aws_vpc_endpoint_service" "vpc_endpoints" {
  count   = length(local.vpc_endpoint_services)
  service = local.vpc_endpoint_services[count.index]
}


resource "aws_vpc_endpoint" "ecs" {
  vpc_id              = aws_vpc.main.id
  count               = length(data.aws_vpc_endpoint_service.vpc_endpoints)
  service_name        = data.aws_vpc_endpoint_service.vpc_endpoints[count.index].service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_subnet[*].id
  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  private_dns_enabled = true
}