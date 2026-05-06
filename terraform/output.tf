output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = module.networking.public_subnet_id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = module.networking.internet_gateway_id
}

output "sg_ingestion_id" {
  description = "Security group ID for ingestion Lambda"
  value       = module.networking.sg_ingestion_id
}

output "sg_quality_id" {
  description = "Security group ID for quality Lambda"
  value       = module.networking.sg_quality_id
}

output "lambda_role_arn" {
  description = "ARN of Lambda execution role"
  value       = module.compute.lambda_role_arn
}

output "lambda_role_name" {
  description = "Name of Lambda execution role"
  value       = module.compute.lambda_role_name
}

output "terraform_state_bucket_name" {
  description = "Name of S3 bucket for Terraform state"
  value       = module.data.state_bucket_name
}

output "terraform_locks_table_name" {
  description = "Name of DynamoDB table for Terraform locks"
  value       = module.data.locks_table_name
}

output "deployment_summary" {
  description = "Summary of deployment configuration"
  value = {
    environment    = var.environment_name
    region         = var.aws_region
    vpc_cidr       = var.vpc_cidr
    public_subnet  = var.public_subnet_cidr
    lambda_memory  = var.lambda_memory_mb
    lambda_timeout = var.lambda_timeout_seconds
  }
}
