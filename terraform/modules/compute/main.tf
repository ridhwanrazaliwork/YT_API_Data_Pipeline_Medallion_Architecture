/*
Compute Module: IAM Roles, Lambda Configuration, Secrets Manager
──────────────────────────────────────────────────────────────────

Purpose:
- Define IAM roles for Lambda functions (with least privilege)
- Define IAM role for Glue jobs
- Define IAM role for Step Functions orchestration
- Configure Lambda VPC networking
*/

# ────────────────────────────────────────────────────────────────────────────
# Data source to get current AWS account ID
# ────────────────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# ────────────────────────────────────────────────────────────────────────────
# IAM Role for Lambda Functions (Ingestion + Quality/Healing)
# ────────────────────────────────────────────────────────────────────────────

## IAM Role: Lambda Execution
# This role allows Lambda functions to run and access required AWS resources.
# It is assumed by Lambda service and grants permissions to access S3 buckets (bronze, silver, gold),
# Glue, Athena, and SNS for the YouTube data pipeline.
resource "aws_iam_role" "lambda_execution" {
  name = "${var.environment_name}-yt-pipeline-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.environment_name}-lambda-role"
  }
}

# Basic Lambda execution policy (CloudWatch Logs)
## Policy Attachment: Lambda Basic Execution
# Grants Lambda permission to write logs to CloudWatch (for monitoring and debugging).
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda VPC Execution Policy (for ENI management)
## Policy Attachment: Lambda VPC Execution
# Allows Lambda to manage network interfaces in a VPC (needed if Lambda runs inside a VPC).
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda S3 Access Policy (with specific buckets)
## Policy: Lambda S3 Access
# Allows Lambda functions to read/write/delete objects in the S3 buckets used for the pipeline.
# This includes the bronze and silver buckets (raw and cleaned data), and Athena results bucket.
resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "${var.environment_name}-lambda-s3-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}-v2",
          "arn:aws:s3:::rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}-v2/*",
          "arn:aws:s3:::rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}-v2",
          "arn:aws:s3:::rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}-v2/*",
          "arn:aws:s3:::rid-yt-data-pipeline-glue-athena-query-result-v2",
          "arn:aws:s3:::rid-yt-data-pipeline-glue-athena-query-result-v2/*"
        ]
      }
    ]
  })
}

# Lambda Glue Access Policy
## Policy: Lambda Glue Access
# Allows Lambda to interact with AWS Glue Data Catalog (get/create/update tables and partitions).
resource "aws_iam_role_policy" "lambda_glue_access" {
  name = "${var.environment_name}-lambda-glue-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueAccess"
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetPartitions",
          "glue:CreatePartition",
          "glue:BatchCreatePartition"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda SNS Access Policy (for alerts)
## Policy: Lambda SNS Access
# Allows Lambda to publish messages to an SNS topic (used for pipeline alerts/notifications).
resource "aws_iam_role_policy" "lambda_sns_access" {
  name = "${var.environment_name}-lambda-sns-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PublishToSNS"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:yt-data-pipeline-alerts-${var.environment_name}-v2"
      }
    ]
  })
}

# Lambda Athena Access Policy
## Policy: Lambda Athena Access
# Allows Lambda to run and get results from Athena queries (for data analysis/validation).
resource "aws_iam_role_policy" "lambda_athena_access" {
  name = "${var.environment_name}-lambda-athena-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:GetWorkGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Secrets Manager Access Policy
## Policy: Lambda Secrets Manager Access
# Allows Lambda to retrieve secrets from AWS Secrets Manager (e.g., YouTube API key).
resource "aws_iam_role_policy" "lambda_secrets_access" {
  name = "${var.environment_name}-lambda-secrets-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.environment_name}/yt-pipeline/*"
      }
    ]
  })
}

# ────────────────────────────────────────────────────────────────────────────
# IAM Role for Glue Jobs
# ────────────────────────────────────────────────────────────────────────────

## IAM Role: Glue Execution
# This role is assumed by AWS Glue jobs. It allows Glue to access S3 buckets (bronze, silver, gold, scripts, athena results)
# for reading/writing data during ETL jobs in the pipeline.
resource "aws_iam_role" "glue_execution" {
  name = "${var.environment_name}-yt-pipeline-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.environment_name}-glue-role"
  }
}

# Glue Execution Policy
## Policy Attachment: Glue Execution
# Grants Glue jobs the basic permissions required to run (managed AWS policy).
resource "aws_iam_role_policy_attachment" "glue_execution" {
  role       = aws_iam_role.glue_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Glue S3 Access Policy (with specific buckets)
## Policy: Glue S3 Access
# Allows Glue jobs to read/write/delete objects in all pipeline S3 buckets (bronze, silver, gold, scripts, athena results).
resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${var.environment_name}-glue-s3-policy"
  role = aws_iam_role.glue_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3FullAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}-v2",
          "arn:aws:s3:::rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}-v2/*",
          "arn:aws:s3:::rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}-v2",
          "arn:aws:s3:::rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}-v2/*",
          "arn:aws:s3:::rid-yt-pipeline-gold-${var.aws_region}-${var.environment_name}-v2",
          "arn:aws:s3:::rid-yt-pipeline-gold-${var.aws_region}-${var.environment_name}-v2/*",
          "arn:aws:s3:::rid-yt-pipeline-script-${var.aws_region}-${var.environment_name}-v2",
          "arn:aws:s3:::rid-yt-pipeline-script-${var.aws_region}-${var.environment_name}-v2/*",
          "arn:aws:s3:::rid-yt-data-pipeline-glue-athena-query-result-v2",
          "arn:aws:s3:::rid-yt-data-pipeline-glue-athena-query-result-v2/*"
        ]
      }
    ]
  })
}

# ────────────────────────────────────────────────────────────────────────────
# CloudWatch Log Groups for Glue Jobs
# ────────────────────────────────────────────────────────────────────────────

## CloudWatch Log Group: Bronze to Silver
# Receives continuous logs from the Bronze-to-Silver Glue job for debugging.
resource "aws_cloudwatch_log_group" "glue_bronze_to_silver" {
  name              = "/aws-glue/${var.environment_name}-yt-data-pipeline-bronze-to-silver"
  retention_in_days = 7

  tags = {
    Name = "${var.environment_name}-bronze-to-silver-logs"
  }
}

## CloudWatch Log Group: Silver to Gold
# Receives continuous logs from the Silver-to-Gold Glue job for debugging.
resource "aws_cloudwatch_log_group" "glue_silver_to_gold" {
  name              = "/aws-glue/${var.environment_name}-yt-data-pipeline-silver-to-gold"
  retention_in_days = 7

  tags = {
    Name = "${var.environment_name}-silver-to-gold-logs"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# Glue Security Configuration for CloudWatch Logging
# ────────────────────────────────────────────────────────────────────────────

## Glue Security Configuration
# Enables continuous logging to CloudWatch for Glue jobs.
resource "aws_glue_security_configuration" "glue_security" {
  name = "${var.environment_name}-glue-security-config"

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "DISABLED"
    }
    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "DISABLED"
    }
    s3_encryption {
      s3_encryption_mode = "DISABLED"
    }
  }
}

# ────────────────────────────────────────────────────────────────────────────
# Glue Jobs
# ────────────────────────────────────────────────────────────────────────────

## Glue Job: Bronze to Silver
# This Glue job transforms raw (bronze) data to cleaned (silver) data.
# The script is stored in the scripts S3 bucket and executed by Glue using the Glue execution role.
# Uses FLEX execution class for cost optimization.
# Continuous logging to CloudWatch is enabled for monitoring and debugging.
resource "aws_glue_job" "bronze_to_silver" {
  name                   = "${var.environment_name}-yt-data-pipeline-bronze-to-silver"
  role_arn               = aws_iam_role.glue_execution.arn
  execution_class        = "FLEX"
  worker_type            = "G.1X"
  number_of_workers      = 2
  glue_version           = "4.0"
  security_configuration = aws_glue_security_configuration.glue_security.name

  command {
    name            = "glueetl"
    script_location = "s3://rid-yt-pipeline-script-${var.aws_region}-${var.environment_name}-v2/bronze_to_silver_statistics.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-glue-datacatalog"          = "true"
    "--conf"                             = "spark.eventLog.rolling.enabled=true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.glue_bronze_to_silver.name
    "--continuous-log-logStreamPrefix"   = "bronze-to-silver"
    "--bronze_database"                  = "yt_pipeline_bronze_${var.environment_name}-v2"
    "--bronze_table"                     = "raw_statistics"
    "--silver_bucket"                    = "rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}-v2"
    "--silver_database"                  = "yt_pipeline_silver_${var.environment_name}-v2"
    "--silver_table"                     = "clean_statistics"
  }

  max_retries = 0
  timeout     = 60

  depends_on = [aws_cloudwatch_log_group.glue_bronze_to_silver]

  tags = {
    Name = "${var.environment_name}-bronze-to-silver"
  }
}

## Glue Job: Silver to Gold
# This Glue job transforms cleaned (silver) data to business-ready (gold) data.
# The script is stored in the scripts S3 bucket and executed by Glue using the Glue execution role.
# Uses FLEX execution class for cost optimization.
# Continuous logging to CloudWatch is enabled for monitoring and debugging.
resource "aws_glue_job" "silver_to_gold" {
  name                   = "${var.environment_name}-yt-data-pipeline-silver-to-gold"
  role_arn               = aws_iam_role.glue_execution.arn
  execution_class        = "FLEX"
  worker_type            = "G.1X"
  number_of_workers      = 2
  glue_version           = "4.0"
  security_configuration = aws_glue_security_configuration.glue_security.name

  command {
    name            = "glueetl"
    script_location = "s3://rid-yt-pipeline-script-${var.aws_region}-${var.environment_name}-v2/silver_to_gold_statistics.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-glue-datacatalog"          = "true"
    "--conf"                             = "spark.eventLog.rolling.enabled=true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.glue_silver_to_gold.name
    "--continuous-log-logStreamPrefix"   = "silver-to-gold"
    "--gold_bucket"                      = "rid-yt-pipeline-gold-${var.aws_region}-${var.environment_name}-v2"
    "--gold_database"                    = "yt_pipeline_gold_${var.environment_name}-v2"
    "--silver_database"                  = "yt_pipeline_silver_${var.environment_name}-v2"
  }

  max_retries = 0
  timeout     = 60

  depends_on = [aws_cloudwatch_log_group.glue_silver_to_gold]

  tags = {
    Name = "${var.environment_name}-silver-to-gold"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# IAM Role for Step Functions
# ────────────────────────────────────────────────────────────────────────────

## IAM Role: Step Functions Execution
# This role is assumed by AWS Step Functions. It allows Step Functions to orchestrate the pipeline by:
# - Invoking Lambda functions
# - Starting and monitoring Glue jobs
# - Publishing alerts to SNS
resource "aws_iam_role" "stepfunction_execution" {
  name = "${var.environment_name}-yt-pipeline-stepfunction-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.environment_name}-stepfunction-role"
  }
}

# Step Functions Execution Policy
## Policy: Step Functions Execution
# Allows Step Functions to:
# - Invoke Lambda functions (for ingestion, transform, quality steps)
# - Start and monitor Glue jobs (for ETL)
# - Publish alerts to SNS topic
resource "aws_iam_role_policy" "stepfunction_execution_policy" {
  name = "${var.environment_name}-stepfunction-execution-policy"
  role = aws_iam_role.stepfunction_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.environment_name}-yt-*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:yt-data-pipeline-alerts-${var.environment_name}-v2"
      }
    ]
  })
}

# ────────────────────────────────────────────────────────────────────────────
# Step Functions State Machine
# ────────────────────────────────────────────────────────────────────────────

## Step Functions State Machine: Pipeline Orchestration
# This resource defines the workflow for the entire data pipeline using AWS Step Functions.
# It references the state machine definition from a JSON template, and uses the Step Functions execution role.
resource "aws_sfn_state_machine" "pipeline_orchestration" {
  name     = "${var.environment_name}-yt-pipeline-orchestration"
  role_arn = aws_iam_role.stepfunction_execution.arn
  definition = templatefile("${path.module}/../../../stepfunctions/pipeline_orchestration.json", {
    environment = var.environment_name
    account_id  = data.aws_caller_identity.current.account_id
    aws_region  = var.aws_region
  })

  tags = {
    Name = "${var.environment_name}-pipeline-orchestration"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# SNS Topic for Pipeline Alerts
# ────────────────────────────────────────────────────────────────────────────

## SNS Topic: Pipeline Alerts
# This topic receives alerts from the pipeline when issues occur (Lambda errors, quality checks fail, etc.).
resource "aws_sns_topic" "pipeline_alerts" {
  name = "yt-data-pipeline-alerts-${var.environment_name}-v2"

  tags = {
    Name = "pipeline-alerts-${var.environment_name}"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# AWS Secrets Manager: YouTube API Key
# ────────────────────────────────────────────────────────────────────────────

## Secrets Manager Secret: YouTube API Key
# Stores the YouTube API key securely. Lambda functions retrieve this at runtime.
# The actual secret value must be set manually via AWS Console or CLI after Terraform apply.
resource "aws_secretsmanager_secret" "youtube_api_key" {
  name_prefix             = "${var.environment_name}/yt-pipeline/youtube-api-key-"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.environment_name}-youtube-api-key"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# Lambda Functions
# ────────────────────────────────────────────────────────────────────────────

## Lambda Function: YouTube Ingestion
# Fetches data from YouTube API and stores raw data in Bronze S3 bucket.
resource "aws_lambda_function" "ingestion" {
  function_name = "${var.environment_name}-yt-ingestion"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = var.lambda_timeout_seconds
  memory_size   = var.lambda_memory_mb

  s3_bucket = "rid-yt-pipeline-script-${var.aws_region}-${var.environment_name}-v2"
  s3_key    = "lambda-ingestion.zip"

  layers = [
    "arn:aws:lambda:${var.aws_region}:336392948345:layer:AWSSDKPandas-Python311:28"
  ]

  # vpc_config {
  #   subnet_ids         = [var.public_subnet_id]
  #   security_group_ids = [var.sg_ingestion_id]
  # }

  environment {
    variables = {
      S3_BUCKET_BRONZE       = "rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}-v2"
      SNS_ALERT_TOPIC_ARN    = aws_sns_topic.pipeline_alerts.arn
      YOUTUBE_API_KEY_SECRET = aws_secretsmanager_secret.youtube_api_key.arn
    }
  }
  ephemeral_storage {
    size = var.lambda_ephemeral_mb
  }

  tags = {
    Name = "${var.environment_name}-ingestion"
  }
}

## Lambda Function: JSON to Parquet Transform
# Converts JSON data from Bronze bucket to Parquet format and stores in Silver bucket.
# Triggered automatically when new files are uploaded to Bronze bucket.
#
# NOTE: Cost-saving decision — Lambda runs outside VPC (no NAT Gateway).
# This avoids ~$35/month NAT Gateway costs for dev.
# For production, attach to a private subnet + NAT Gateway or use VPC Endpoints
# to restrict network access for security.
resource "aws_lambda_function" "transform" {
  function_name = "${var.environment_name}-yt-transform"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = var.lambda_timeout_seconds
  memory_size   = var.lambda_memory_mb

  s3_bucket = "rid-yt-pipeline-script-${var.aws_region}-${var.environment_name}-v2"
  s3_key    = "lambda-transform.zip"

  layers = [
    "arn:aws:lambda:${var.aws_region}:336392948345:layer:AWSSDKPandas-Python311:28"
  ]

  environment {
    variables = {
      GLUE_DB_SILVER       = "yt_pipeline_silver_${var.environment_name}-v2"
      GLUE_TABLE_REFERENCE = "clean_reference_data"
      S3_BUCKET_SILVER     = "rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}-v2"
      SNS_ALERT_TOPIC_ARN  = aws_sns_topic.pipeline_alerts.arn
    }
  }
  ephemeral_storage {
    size = var.lambda_ephemeral_mb
  }
  tags = {
    Name = "${var.environment_name}-transform"
  }
}

## Lambda Function: Data Quality Check
# Validates data in Silver bucket using Athena queries.
# Publishes alerts if data quality issues are detected.
#
# NOTE: Cost-saving decision — Lambda runs outside VPC (no NAT Gateway).
# This avoids ~$35/month NAT Gateway costs for dev.
# For production, attach to a private subnet + NAT Gateway or use VPC Endpoints
# to restrict network access for security.
resource "aws_lambda_function" "quality" {
  function_name = "${var.environment_name}-yt-quality"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = var.lambda_timeout_seconds
  memory_size   = var.lambda_memory_mb

  s3_bucket = "rid-yt-pipeline-script-${var.aws_region}-${var.environment_name}-v2"
  s3_key    = "lambda-quality.zip"

  layers = [
    "arn:aws:lambda:${var.aws_region}:336392948345:layer:AWSSDKPandas-Python311:28"
  ]

  environment {
    variables = {
      ATHENA_WORKGROUP    = "primary"
      DQ_MAX_NULL_PERCENT = "5"
      DQ_MIN_ROW_COUNT    = "10"
      S3_OUTPUT           = "s3://rid-yt-data-pipeline-glue-athena-query-result-v2/athena-results/"
      SNS_ALERT_TOPIC_ARN = aws_sns_topic.pipeline_alerts.arn
    }
  }
  ephemeral_storage {
    size = var.lambda_ephemeral_mb
  }
  tags = {
    Name = "${var.environment_name}-quality"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# Lambda Permission: S3 Trigger for Transform Function
# ────────────────────────────────────────────────────────────────────────────

## Lambda Permission: S3 Invoke
# Allows S3 Bronze bucket to invoke the Transform Lambda function when new files are uploaded.
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transform.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}-v2"
}

# ────────────────────────────────────────────────────────────────────────────
# Lambda Configuration (for reference)
# ────────────────────────────────────────────────────────────────────────────

# These are just configuration values for reference.

locals {
  ingestion_lambda_config = {
    function_name = "${var.environment_name}-yt-ingestion"
    role_arn      = aws_iam_role.lambda_execution.arn
    timeout       = var.lambda_timeout_seconds
    memory_size   = var.lambda_memory_mb
    runtime       = "python3.11"
    vpc_config    = null
  }

  quality_lambda_config = {
    function_name = "${var.environment_name}-yt-quality"
    role_arn      = aws_iam_role.lambda_execution.arn
    timeout       = var.lambda_timeout_seconds
    memory_size   = var.lambda_memory_mb
    runtime       = "python3.11"
    vpc_config    = null
  }

  transform_lambda_config = {
    function_name = "${var.environment_name}-yt-transform"
    role_arn      = aws_iam_role.lambda_execution.arn
    timeout       = var.lambda_timeout_seconds
    memory_size   = var.lambda_memory_mb
    runtime       = "python3.11"
    vpc_config    = null
  }
}
