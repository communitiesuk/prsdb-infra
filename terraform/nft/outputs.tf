output "public_subnet_ids" {
  value       = module.networking.public_subnets[*].id
  description = "The ids of the public subnets"
}

output "vpc_id" {
  value       = module.networking.vpc.id
  description = "The id of the vpc"
}

output "load_balancer_dns_name" {
  value       = module.frontdoor.load_balancer.dns_name
  description = "The domain name of the application load balancer"
}

output "cloudfront_dns_name" {
  value       = module.frontdoor.cloudfront_dns_name
  description = "The domain name of the cloudfront distribution"
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

output "performance_runner_cloudfront_ip_set_arn" {
  value       = module.frontdoor.performance_runner_cloudfront_ip_set_arn
  description = "ARN of the workflow-managed CloudFront performance runner IP set"
}

output "performance_runner_cloudfront_ip_set_id" {
  value       = module.frontdoor.performance_runner_cloudfront_ip_set_id
  description = "ID of the workflow-managed CloudFront performance runner IP set"
}

output "performance_runner_cloudfront_ip_set_name" {
  value       = module.frontdoor.performance_runner_cloudfront_ip_set_name
  description = "Name of the workflow-managed CloudFront performance runner IP set"
}

output "performance_runner_regional_ip_set_arn" {
  value       = module.frontdoor.performance_runner_regional_ip_set_arn
  description = "ARN of the workflow-managed regional performance runner IP set"
}

output "performance_runner_regional_ip_set_id" {
  value       = module.frontdoor.performance_runner_regional_ip_set_id
  description = "ID of the workflow-managed regional performance runner IP set"
}

output "performance_runner_regional_ip_set_name" {
  value       = module.frontdoor.performance_runner_regional_ip_set_name
  description = "Name of the workflow-managed regional performance runner IP set"
}

output "simulator_alb_security_group_id" {
  value       = module.frontdoor.load_balancer.simulator_security_group_id
  description = "ID of the simulator ALB security group"
}

output "simulator_service_arn" {
  value       = var.task_definition_created ? module.one_login_simulator[0].service_arn : null
  description = "ARN of the One Login simulator ECS service"
}

output "simulator_service_name" {
  value       = var.task_definition_created ? module.one_login_simulator[0].service_name : null
  description = "Name of the One Login simulator ECS service"
}

output "performance_runner_access_role_arn" {
  value       = module.github_actions_access.performance_runner_access_role_arn
  description = "ARN of the performance runner network access role"
}

output "one_login_simulator_mirror_role_arn" {
  value       = module.github_actions_access.one_login_simulator_mirror_role_arn
  description = "ARN of the NFT One Login simulator image mirror role"
}

output "one_login_simulator_repository_url" {
  value       = module.ecr.one_login_simulator_repository_url
  description = "URL of the NFT One Login simulator ECR repository"
}