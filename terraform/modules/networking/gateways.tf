resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "internet-gateway-${var.environment_name}"
  }
}

resource "aws_eip" "nat_gateway" {
  count = var.number_of_availability_zones
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  count = var.number_of_availability_zones
  allocation_id = element(aws_eip.nat_gateway[*].id, count.index)
  subnet_id     = aws_subnet.nat_gateway[count.index].id

  tags = {
    Name = "nat-gateway-${var.environment_name}-${data.aws_availability_zones.available.names[count.index]}"
  }
}