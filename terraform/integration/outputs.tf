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

output "cloudfront_certificate_validation" {
  value       = module.certificates.cloudfront_certificate_validation
  description = "The domain validation objects for the cloudfront certificate"
}

output "load_balancer_certificate_validation" {
  value       = module.certificates.load_balancer_certificate_validation
  description = "The domain validation objects for the load balancer certificate"
}

output "ecr_repository_url" {
  value       = module.ecr.ecr_repository_url
  description = "The url of the ecr repository for this environment"
}