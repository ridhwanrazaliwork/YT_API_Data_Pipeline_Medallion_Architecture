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

output "sns_topic_arn" {
  description = "ARN of SNS topic for pipeline alerts"
  value       = aws_sns_topic.pipeline_alerts.arn
}

output "sns_topic_name" {
  description = "Name of SNS topic for pipeline alerts"
  value       = aws_sns_topic.pipeline_alerts.name
}

output "youtube_api_key_secret_arn" {
  description = "ARN of Secrets Manager secret for YouTube API key"
  value       = aws_secretsmanager_secret.youtube_api_key.arn
}

output "ingestion_lambda_arn" {
  description = "ARN of ingestion Lambda function"
  value       = aws_lambda_function.ingestion.arn
}

output "ingestion_lambda_name" {
  description = "Name of ingestion Lambda function"
  value       = aws_lambda_function.ingestion.function_name
}

output "transform_lambda_arn" {
  description = "ARN of transform Lambda function"
  value       = aws_lambda_function.transform.arn
}

output "transform_lambda_name" {
  description = "Name of transform Lambda function"
  value       = aws_lambda_function.transform.function_name
}

output "quality_lambda_arn" {
  description = "ARN of quality Lambda function"
  value       = aws_lambda_function.quality.arn
}

output "quality_lambda_name" {
  description = "Name of quality Lambda function"
  value       = aws_lambda_function.quality.function_name
}

output "stepfunction_state_machine_arn" {
  description = "ARN of Step Functions state machine"
  value       = aws_sfn_state_machine.pipeline_orchestration.arn
}

output "bronze_to_silver_glue_job_name" {
  description = "Name of Bronze to Silver Glue job"
  value       = aws_glue_job.bronze_to_silver.name
}

output "silver_to_gold_glue_job_name" {
  description = "Name of Silver to Gold Glue job"
  value       = aws_glue_job.silver_to_gold.name
}
