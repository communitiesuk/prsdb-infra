data "aws_vpc_endpoint_service" "ssm" {
  service = "ssm"
}

data "aws_vpc_endpoint_service" "ssmmessages" {
  service = "ssmmessages"
}

data "aws_vpc_endpoint_service" "ec2messages" {
  service = "ec2messages"
}