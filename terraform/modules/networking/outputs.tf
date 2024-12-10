output "vpc" {
  value       = aws_vpc.main
  description = "Main AWS VPC"
}

output "nat_gateway_ip" {
  value = aws_eip.nat_gateway[*].public_ip
}

output "public_subnet" {
  value       = aws_subnet.public_subnet
  description = "Public /22 subnet for alb listeners"
}

output "private_subnet" {
  value       = aws_subnet.private_subnet
  description = "Private /22 subnet for ECS and bastian host"
}

output "isolated_subnets" {
  value       = aws_subnet.isolated_subnet
  description = "var.number_of_isolated_subnets /22 subnets for db and redis - 2 required when using multi-AZ rds"
}

