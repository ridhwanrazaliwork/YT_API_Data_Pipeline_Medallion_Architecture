output "lambda_role_arn" {
  description = "ARN of Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_role_name" {
  description = "Name of Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

output "glue_role_arn" {
  description = "ARN of Glue execution role"
  value       = aws_iam_role.glue_execution.arn
}

output "glue_role_name" {
  description = "Name of Glue execution role"
  value       = aws_iam_role.glue_execution.name
}

output "ingestion_lambda_config" {
  description = "Configuration for ingestion Lambda"
  value       = local.ingestion_lambda_config
}

output "quality_lambda_config" {
  description = "Configuration for quality Lambda"
  value = {
    function_name = local.quality_lambda_config.function_name
    role_arn      = local.quality_lambda_config.role_arn
    timeout       = local.quality_lambda_config.timeout
    memory_size   = local.quality_lambda_config.memory_size
    runtime       = local.quality_lambda_config.runtime
    vpc_config    = local.quality_lambda_config.vpc_config
    # Don't expose environment variables in output (sensitive)
  }
}
