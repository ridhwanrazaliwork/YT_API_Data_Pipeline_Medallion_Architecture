/*
Data Module: S3 Buckets (Pipeline + State), DynamoDB Locks
──────────────────────────────────────────────────────────

Purpose:
- S3 buckets for data pipeline layers (Bronze, Silver, Gold, Scripts, Athena results)
- S3 bucket to store Terraform state (with versioning & encryption)
- DynamoDB table to manage concurrent access locks
*/

# ────────────────────────────────────────────────────────────────────────────
# Data Pipeline S3 Buckets (Bronze, Silver, Gold, Scripts, Athena Results)
# ────────────────────────────────────────────────────────────────────────────

# Bronze Layer — Raw data
resource "aws_s3_bucket" "bronze" {
  bucket = "rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}-v2"

  tags = {
    Name = "bronze-layer-${var.environment_name}"
  }
}

# Silver Layer — Cleaned data
resource "aws_s3_bucket" "silver" {
  bucket = "rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}-v2"

  tags = {
    Name = "silver-layer-${var.environment_name}"
  }
}

# Gold Layer — Aggregated data
resource "aws_s3_bucket" "gold" {
  bucket = "rid-yt-pipeline-gold-${var.aws_region}-${var.environment_name}-v2"

  tags = {
    Name = "gold-layer-${var.environment_name}"
  }
}

# Scripts — Glue job scripts and other code
resource "aws_s3_bucket" "scripts" {
  bucket = "rid-yt-pipeline-script-${var.aws_region}-${var.environment_name}-v2"

  tags = {
    Name = "scripts-${var.environment_name}"
  }
}

# Athena Query Results
resource "aws_s3_bucket" "athena_results" {
  bucket = "rid-yt-data-pipeline-glue-athena-query-result-v2"

  tags = {
    Name = "athena-results"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# S3 Bucket for Terraform State
# ────────────────────────────────────────────────────────────────────────────

# Note: This resource might conflict if bucket already exists.
# If you pre-created the bucket via AWS CLI, comment out this resource.

resource "aws_s3_bucket" "terraform_state" {
  bucket = "yt-pipeline-terraform-state-${var.aws_region}-v2"

  tags = {
    Name = "terraform-state-${var.environment_name}"
  }
}

# Enable versioning (restore previous state if needed)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access (security)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ────────────────────────────────────────────────────────────────────────────
# DynamoDB Table for Terraform Locks
# ────────────────────────────────────────────────────────────────────────────

# This table prevents concurrent terraform apply operations
# (which could corrupt state)

resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks-v2"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "terraform-locks-${var.environment_name}"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# Data Outputs
# ────────────────────────────────────────────────────────────────────────────

# Note: These outputs are for reference. The actual backend configuration
# lives in root terraform/backend.tf
