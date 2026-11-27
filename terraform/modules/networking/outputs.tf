output "vpc" {
  value       = aws_vpc.main
  description = "The AWS VPC"
}

output "nat_gateway_ip" {
  value       = try(aws_eip.nat_gateway[0].public_ip, null)
  description = "The IP address of the legacy zonal NAT gateway, when present"
}

output "nat_gateway_ips" {
  value       = var.use_regional_nat_gateway ? aws_eip.regional_nat_gateway[*].public_ip : [aws_eip.nat_gateway[0].public_ip]
  description = "The IP addresses used by the NAT gateway"
}

output "vpc_endpoint_security_group_id" {
  value       = aws_security_group.aws_service_vpc_endpoints.id
  description = "Security group ID for AWS interface VPC endpoints"
}

output "public_subnets" {
  value       = aws_subnet.public_subnet
  description = "Public /22 subnets for alb listeners"
}

output "private_subnets" {
  value       = aws_subnet.private_subnet
  description = "Private /22 subnets for ECS and bastian host"
}

output "isolated_subnets" {
  value       = aws_subnet.isolated_subnet
  description = "var.number_of_isolated_subnets /22 subnets for the database and cache - 2 required when using multi-AZ rds"
}

output "db_subnet_group_name" {
  value       = aws_db_subnet_group.main.name
  description = "Name of the db subnet group"
}
