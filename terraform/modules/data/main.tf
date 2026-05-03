/*
Data Module: S3 Buckets (Pipeline + State), DynamoDB Locks
──────────────────────────────────────────────────────────

Purpose to create:
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
# AWS Glue Catalog: Databases & Tables
# ────────────────────────────────────────────────────────────────────────────

## Glue Database: Bronze Layer
# Contains raw data tables as they are ingested from external sources.
resource "aws_glue_catalog_database" "bronze" {
  name            = "yt_pipeline_bronze_${var.environment_name}-v2"
  description     = "Bronze layer - raw data from YouTube API"
  catalog_id      = data.aws_caller_identity.current.account_id

  tags = {
    Name = "bronze-db-${var.environment_name}"
  }
}

## Glue Database: Silver Layer
# Contains cleaned, deduplicated, and validated data.
resource "aws_glue_catalog_database" "silver" {
  name            = "yt_pipeline_silver_${var.environment_name}-v2"
  description     = "Silver layer - cleaned and validated data"
  catalog_id      = data.aws_caller_identity.current.account_id

  tags = {
    Name = "silver-db-${var.environment_name}"
  }
}

## Glue Database: Gold Layer
# Contains aggregated, business-ready data for analytics.
resource "aws_glue_catalog_database" "gold" {
  name            = "yt_pipeline_gold_${var.environment_name}-v2"
  description     = "Gold layer - aggregated analytics data"
  catalog_id      = data.aws_caller_identity.current.account_id

  tags = {
    Name = "gold-db-${var.environment_name}"
  }
}

## Glue Table: Bronze - Raw Statistics
# Raw YouTube statistics data as ingested from API.
resource "aws_glue_catalog_table" "bronze_raw_statistics" {
  name          = "raw_statistics"
  database_name = aws_glue_catalog_database.bronze.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}-v2/youtube/raw_statistics/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
    }

    columns {
      name = "video_id"
      type = "string"
    }
    columns {
      name = "trending_date"
      type = "string"
    }
    columns {
      name = "title"
      type = "string"
    }
    columns {
      name = "channel_title"
      type = "string"
    }
    columns {
      name = "category_id"
      type = "int"
    }
    columns {
      name = "publish_time"
      type = "string"
    }
    columns {
      name = "tags"
      type = "string"
    }
    columns {
      name = "views"
      type = "bigint"
    }
    columns {
      name = "likes"
      type = "bigint"
    }
    columns {
      name = "dislikes"
      type = "bigint"
    }
    columns {
      name = "comment_count"
      type = "bigint"
    }
  }

  parameters = {
    "classification" = "csv"
  }
}

## Glue Table: Bronze - Reference Data
# Reference data such as category mappings.
resource "aws_glue_catalog_table" "bronze_reference_data" {
  name          = "raw_statistics_reference_data"
  database_name = aws_glue_catalog_database.bronze.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}-v2/youtube/raw_statistics_reference_data/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
    }

    columns {
      name = "category_id"
      type = "int"
    }
    columns {
      name = "category_name"
      type = "string"
    }
  }

  parameters = {
    "classification" = "json"
  }
}

## Glue Table: Silver - Clean Statistics
# Cleaned and validated YouTube statistics.
resource "aws_glue_catalog_table" "silver_clean_statistics" {
  name          = "clean_statistics"
  database_name = aws_glue_catalog_database.silver.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}-v2/youtube/statistics/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "video_id"
      type = "string"
    }
    columns {
      name = "trending_date"
      type = "string"
    }
    columns {
      name = "title"
      type = "string"
    }
    columns {
      name = "channel_title"
      type = "string"
    }
    columns {
      name = "category_id"
      type = "int"
    }
    columns {
      name = "views"
      type = "bigint"
    }
    columns {
      name = "likes"
      type = "bigint"
    }
    columns {
      name = "comment_count"
      type = "bigint"
    }
  }

  parameters = {
    "classification" = "parquet"
  }
}

## Glue Table: Silver - Reference Data
# Cleaned reference data.
resource "aws_glue_catalog_table" "silver_reference_data" {
  name          = "clean_reference_data"
  database_name = aws_glue_catalog_database.silver.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}-v2/youtube/reference_data/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "category_id"
      type = "int"
    }
    columns {
      name = "category_name"
      type = "string"
    }
  }

  parameters = {
    "classification" = "parquet"
  }
}

## Glue Table: Gold - Category Analytics
# Aggregated analytics by category.
resource "aws_glue_catalog_table" "gold_category_analytics" {
  name          = "category_analytics"
  database_name = aws_glue_catalog_database.gold.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://rid-yt-pipeline-gold-${var.aws_region}-${var.environment_name}-v2/youtube/category_analytics/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "category_id"
      type = "int"
    }
    columns {
      name = "category_name"
      type = "string"
    }
    columns {
      name = "avg_views"
      type = "double"
    }
    columns {
      name = "total_views"
      type = "bigint"
    }
  }

  parameters = {
    "classification" = "parquet"
  }
}

## Glue Table: Gold - Channel Analytics
# Aggregated analytics by channel.
resource "aws_glue_catalog_table" "gold_channel_analytics" {
  name          = "channel_analytics"
  database_name = aws_glue_catalog_database.gold.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://rid-yt-pipeline-gold-${var.aws_region}-${var.environment_name}-v2/youtube/channel_analytics/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "channel_title"
      type = "string"
    }
    columns {
      name = "avg_views"
      type = "double"
    }
    columns {
      name = "total_views"
      type = "bigint"
    }
    columns {
      name = "video_count"
      type = "int"
    }
  }

  parameters = {
    "classification" = "parquet"
  }
}

## Glue Table: Gold - Trending Analytics
# Trending content analytics.
resource "aws_glue_catalog_table" "gold_trending_analytics" {
  name          = "trending_analytics"
  database_name = aws_glue_catalog_database.gold.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://rid-yt-pipeline-gold-${var.aws_region}-${var.environment_name}-v2/youtube/trending_analytics/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "video_id"
      type = "string"
    }
    columns {
      name = "title"
      type = "string"
    }
    columns {
      name = "channel_title"
      type = "string"
    }
    columns {
      name = "views"
      type = "bigint"
    }
    columns {
      name = "trending_score"
      type = "double"
    }
  }

  parameters = {
    "classification" = "parquet"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# S3 Event Notification: Bronze Bucket → Lambda Transform
# ────────────────────────────────────────────────────────────────────────────

## S3 Bucket Notification: Bronze Bucket
# Automatically triggers the Transform Lambda function when JSON files are uploaded to the bronze bucket.
# This enables real-time processing of newly ingested data.
# resource "aws_s3_bucket_notification" "bronze_notifications" {
#   bucket = aws_s3_bucket.bronze.id

#   lambda_function {
#     lambda_function_arn = var.transform_lambda_arn
#     events              = ["s3:ObjectCreated:*"]
#     filter_prefix       = "youtube/raw_statistics_reference_data/"
#     filter_suffix       = ".json"
#   }
# }

# ────────────────────────────────────────────────────────────────────────────
# Data source to get current AWS account ID
# ────────────────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# ────────────────────────────────────────────────────────────────────────────
# Data Outputs
# ────────────────────────────────────────────────────────────────────────────

# Note: These outputs are for reference. The actual backend configuration
# lives in root terraform/backend.tf
