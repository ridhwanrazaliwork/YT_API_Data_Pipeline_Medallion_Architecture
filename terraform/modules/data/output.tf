output "state_bucket_name" {
  description = "Name of S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "bronze_bucket_name" {
  description = "Name of S3 bucket for Bronze layer data"
  value       = aws_s3_bucket.bronze.id
}

output "silver_bucket_name" {
  description = "Name of S3 bucket for Silver layer data"
  value       = aws_s3_bucket.silver.id
}

output "gold_bucket_name" {
  description = "Name of S3 bucket for Gold layer data"
  value       = aws_s3_bucket.gold.id
}

output "scripts_bucket_name" {
  description = "Name of S3 bucket for Glue scripts"
  value       = aws_s3_bucket.scripts.id
}

output "athena_results_bucket_name" {
  description = "Name of S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.id
}

output "locks_table_name" {
  description = "Name of DynamoDB table for Terraform locks"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "locks_table_arn" {
  description = "ARN of DynamoDB table for Terraform locks"
  value       = aws_dynamodb_table.terraform_locks.arn
}
