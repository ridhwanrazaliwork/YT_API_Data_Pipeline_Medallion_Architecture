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

# Lambda S3 Access Policy (with specific buckets)
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
          "arn:aws:s3:::rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}",
          "arn:aws:s3:::rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}/*",
          "arn:aws:s3:::rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}",
          "arn:aws:s3:::rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}/*",
          "arn:aws:s3:::rid-yt-data-pipeline-glue-athena-query-result",
          "arn:aws:s3:::rid-yt-data-pipeline-glue-athena-query-result/*"
        ]
      }
    ]
  })
}

# Lambda Glue Access Policy
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
        Resource = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:yt-data-pipeline-alerts-${var.environment_name}"
      }
    ]
  })
}

# Lambda Athena Access Policy
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

# Glue S3 Access Policy (with specific buckets)
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
# Glue Jobs
# ────────────────────────────────────────────────────────────────────────────

resource "aws_glue_job" "bronze_to_silver" {
  name     = "${var.environment_name}-yt-data-pipeline-bronze-to-silver"
  role_arn = aws_iam_role.glue_execution.arn

  command {
    name            = "glueetl"
    script_location = "s3://rid-yt-pipeline-script-${var.aws_region}-${var.environment_name}-v2/bronze_to_silver_statistics.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-bookmark-option" = "job-bookmark-enable"
    "--enable-metrics"      = "true"
    "--enable-glue-datacatalog" = "true"
  }

  max_retries = 0
  timeout     = 60

  tags = {
    Name = "${var.environment_name}-bronze-to-silver"
  }
}

resource "aws_glue_job" "silver_to_gold" {
  name     = "${var.environment_name}-yt-data-pipeline-silver-to-gold"
  role_arn = aws_iam_role.glue_execution.arn

  command {
    name            = "glueetl"
    script_location = "s3://rid-yt-pipeline-script-${var.aws_region}-${var.environment_name}-v2/silver_to_gold_statistics.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-bookmark-option" = "job-bookmark-enable"
    "--enable-metrics"      = "true"
    "--enable-glue-datacatalog" = "true"
  }

  max_retries = 0
  timeout     = 60

  tags = {
    Name = "${var.environment_name}-silver-to-gold"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# IAM Role for Step Functions
# ────────────────────────────────────────────────────────────────────────────

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
resource "aws_iam_role_policy" "stepfunction_execution_policy" {
  name = "${var.environment_name}-stepfunction-execution-policy"
  role = aws_iam_role.stepfunction_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:yt-data-pipeline-*"
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
        Effect = "Allow"
        Action = "sns:Publish"
        Resource = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:yt-data-pipeline-alerts-${var.environment_name}"
      }
    ]
  })
}

# ────────────────────────────────────────────────────────────────────────────
# Step Functions State Machine
# ────────────────────────────────────────────────────────────────────────────

resource "aws_sfn_state_machine" "pipeline_orchestration" {
  name       = "${var.environment_name}-yt-pipeline-orchestration"
  role_arn   = aws_iam_role.stepfunction_execution.arn
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

  transform_lambda_config = {
    function_name = "${var.environment_name}-yt-transform"
    role_arn      = aws_iam_role.lambda_execution.arn
    timeout       = var.lambda_timeout_seconds
    memory_size   = var.lambda_memory_mb
    runtime       = "python3.11"
    vpc_config = {
      subnet_ids         = [var.public_subnet_id]
      security_group_ids = [var.sg_ingestion_id]
    }
  }
}
