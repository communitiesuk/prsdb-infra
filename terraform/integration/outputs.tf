output "public_subnet_ids" {
  value = module.networking.public_subnets[*].id
}

output "vpc_id" {
  value = module.networking.vpc.id
}

output "load_balancer_dns_name" {
  value = module.frontdoor.load_balancer.dns_name
}

output "cloudfront_dns_name" {
  value = module.frontdoor.cloudfront_dns_name
}