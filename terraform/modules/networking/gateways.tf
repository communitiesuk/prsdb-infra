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
  count  = var.use_regional_nat_gateway && !var.retain_zonal_nat_gateway ? 0 : 1
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = var.use_regional_nat_gateway && !var.retain_zonal_nat_gateway ? 0 : 1
  allocation_id = aws_eip.nat_gateway[0].id
  subnet_id     = aws_subnet.nat_gateway.id

  tags = {
    Name = "nat-gateway-${var.environment_name}"
  }
}

resource "aws_eip" "regional_nat_gateway" {
  count  = var.use_regional_nat_gateway ? var.number_of_availability_zones : 0
  domain = "vpc"

  tags = {
    Name = "regional-nat-gateway-${var.environment_name}-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_nat_gateway" "regional" {
  count             = var.use_regional_nat_gateway ? 1 : 0
  availability_mode = "regional"
  connectivity_type = "public"
  vpc_id            = aws_vpc.main.id

  dynamic "availability_zone_address" {
    for_each = aws_eip.regional_nat_gateway
    content {
      availability_zone = data.aws_availability_zones.available.names[availability_zone_address.key]
      allocation_ids    = [availability_zone_address.value.id]
    }
  }

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "regional-nat-gateway-${var.environment_name}"
  }
}

moved {
  from = aws_eip.nat_gateway
  to   = aws_eip.nat_gateway[0]
}

moved {
  from = aws_nat_gateway.nat_gateway
  to   = aws_nat_gateway.nat_gateway[0]
}