output "safe_bucket_arn" {
  value       = module.uploaded_files_bucket.bucket_arn
  description = "ARN of the bucket holding uploaded files that have passed virus scanning"
}

output "safe_bucket_name" {
  value       = module.uploaded_files_bucket.bucket
  description = "Name of the bucket holding uploaded files that have passed virus scanning"
}
