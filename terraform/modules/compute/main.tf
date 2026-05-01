/*
Compute Module: IAM Roles, Lambda Configuration, Secrets Manager
──────────────────────────────────────────────────────────────────

Purpose:
- Define IAM roles for Lambda functions (with least privilege)
- Store Groq API key in Secrets Manager
- Configure Lambda VPC networking
*/

# ────────────────────────────────────────────────────────────────────────────
# IAM Role for Lambda Functions (Ingestion + Quality/Healing)
# ────────────────────────────────────────────────────────────────────────────

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
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda VPC Execution Policy (for ENI management)
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# S3 Access Policy (for ingestion and quality checks)
resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "${var.environment_name}-lambda-s3-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::rid-yt-data-pipeline-*",
          "arn:aws:s3:::rid-yt-data-pipeline-*/*"
        ]
      },
      {
        Sid    = "AthenaQueryAccess"
        Effect = "Allow"
        Action = [
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StartQueryExecution",
          "athena:StopQueryExecution"
        ]
        Resource = "*"
      },
      {
        Sid    = "GlueAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:BatchGetPartition",
          "glue:GetPartitions"
        ]
        Resource = "*"
      }
    ]
  })
}


# SNS Access Policy (for alerts)
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
        Resource = "arn:aws:sns:*:*:yt-*"
      }
    ]
  })
}

# ────────────────────────────────────────────────────────────────────────────
# IAM Role for Glue Jobs
# ────────────────────────────────────────────────────────────────────────────

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
resource "aws_iam_role_policy_attachment" "glue_execution" {
  role       = aws_iam_role.glue_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Glue S3 Access Policy
resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${var.environment_name}-glue-s3-policy"
  role = aws_iam_role.glue_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DataAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::rid-yt-data-pipeline-*",
          "arn:aws:s3:::rid-yt-data-pipeline-*/*"
        ]
      }
    ]
  })
}

# ────────────────────────────────────────────────────────────────────────────
# Lambda Configuration (for reference, actual deployment via CI/CD)
# ────────────────────────────────────────────────────────────────────────────

# These are just configuration values. The actual Lambda functions
# are deployed via GitHub Actions CI/CD.

locals {
  ingestion_lambda_config = {
    function_name = "${var.environment_name}-yt-ingestion"
    role_arn      = aws_iam_role.lambda_execution.arn
    timeout       = var.lambda_timeout_seconds
    memory_size   = var.lambda_memory_mb
    runtime       = "python3.11"
    vpc_config = {
      subnet_ids         = [var.public_subnet_id]
      security_group_ids = [var.sg_ingestion_id]
    }
  }

  quality_lambda_config = {
    function_name = "${var.environment_name}-yt-quality"
    role_arn      = aws_iam_role.lambda_execution.arn
    timeout       = var.lambda_timeout_seconds
    memory_size   = var.lambda_memory_mb
    runtime       = "python3.11"
    vpc_config = {
      subnet_ids         = [var.public_subnet_id]
      security_group_ids = [var.sg_quality_id]
    }
  }
}
