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
  name         = "terraform-locks-v2"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

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
  name        = "yt_pipeline_bronze_${var.environment_name}-v2"
  description = "Bronze layer - raw data from YouTube API"
  catalog_id  = data.aws_caller_identity.current.account_id

  tags = {
    Name = "bronze-db-${var.environment_name}"
  }
}

## Glue Database: Silver Layer
# Contains cleaned, deduplicated, and validated data.
resource "aws_glue_catalog_database" "silver" {
  name        = "yt_pipeline_silver_${var.environment_name}-v2"
  description = "Silver layer - cleaned and validated data"
  catalog_id  = data.aws_caller_identity.current.account_id

  tags = {
    Name = "silver-db-${var.environment_name}"
  }
}

## Glue Database: Gold Layer
# Contains aggregated, business-ready data for analytics.
resource "aws_glue_catalog_database" "gold" {
  name        = "yt_pipeline_gold_${var.environment_name}-v2"
  description = "Gold layer - aggregated analytics data"
  catalog_id  = data.aws_caller_identity.current.account_id

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
    columns {
      name = "thumbnail_link"
      type = "string"
    }
    columns {
      name = "comments_disabled"
      type = "boolean"
    }
    columns {
      name = "ratings_disabled"
      type = "boolean"
    }
    columns {
      name = "video_error_or_removed"
      type = "boolean"
    }
    columns {
      name = "description"
      type = "string"
    }
  }

  partition_keys {
    name = "region"
    type = "string"
  }

  parameters = {
    "classification" = "csv"
  }

  lifecycle {
    ignore_changes = [
      parameters,
    ]
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
      name = "kind"
      type = "string"
    }
    columns {
      name = "etag"
      type = "string"
    }
    columns {
      name = "items"
      type = "array<struct<kind:string,etag:string,id:string,snippet:struct<channelId:string,title:string,assignable:boolean>>>"
    }
  }
  partition_keys {
    name = "region"
    type = "string"
  }

  parameters = {
    "classification" = "json"
  }

  lifecycle {
    ignore_changes = [
      parameters,
    ]
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
    columns {
      name = "thumbnail_link"
      type = "string"
    }
    columns {
      name = "comments_disabled"
      type = "boolean"
    }
    columns {
      name = "ratings_disabled"
      type = "boolean"
    }
    columns {
      name = "video_error_or_removed"
      type = "boolean"
    }
    columns {
      name = "description"
      type = "string"
    }
    columns {
      name = "trending_date_parsed"
      type = "date"
    }
    columns {
      name = "like_ratio"
      type = "double"
    }
    columns {
      name = "engagement_rate"
      type = "double"
    }
    columns {
      name = "_processed_at"
      type = "timestamp"
    }
    columns {
      name = "_job_name"
      type = "string"
    }
  }

  partition_keys {
    name = "region"
    type = "string"
  }

  parameters = {
    "classification" = "parquet"
  }

  lifecycle {
    ignore_changes = [
      parameters,
    ]
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
      name = "kind"
      type = "string"
    }
    columns {
      name = "etag"
      type = "string"
    }
    columns {
      name = "id"
      type = "string"
    }
    columns {
      name = "snippet_title"
      type = "string"
    }
    columns {
      name = "snippet_assignable"
      type = "boolean"
    }
    columns {
      name = "snippet_channelid"
      type = "string"
    }
    columns {
      name = "_ingestion_timestamp"
      type = "string"
    }
    columns {
      name = "_source_file"
      type = "string"
    }
  }

  partition_keys {
    name = "region"
    type = "string"
  }

  parameters = {
    "classification" = "parquet"
  }

  lifecycle {
    ignore_changes = [
      parameters,
    ]
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
      name = "category_name"
      type = "string"
    }
    columns {
      name = "category_id"
      type = "bigint"
    }
    columns {
      name = "trending_date_parsed"
      type = "date"
    }
    columns {
      name = "video_count"
      type = "bigint"
    }
    columns {
      name = "total_views"
      type = "bigint"
    }
    columns {
      name = "total_likes"
      type = "bigint"
    }
    columns {
      name = "total_comments"
      type = "bigint"
    }
    columns {
      name = "avg_engagement_rate"
      type = "double"
    }
    columns {
      name = "unique_channels"
      type = "bigint"
    }
    columns {
      name = "view_share_pct"
      type = "double"
    }
    columns {
      name = "_aggregated_at"
      type = "timestamp"
    }
  }

  partition_keys {
    name = "region"
    type = "string"
  }
  parameters = {
    "classification" = "parquet"
  }
  lifecycle {
    ignore_changes = [
      parameters,
    ]
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
      name = "total_videos"
      type = "bigint"
    }
    columns {
      name = "total_views"
      type = "bigint"
    }
    columns {
      name = "total_likes"
      type = "bigint"
    }
    columns {
      name = "total_comments"
      type = "bigint"
    }
    columns {
      name = "avg_views_per_video"
      type = "double"
    }
    columns {
      name = "avg_engagement_rate"
      type = "double"
    }
    columns {
      name = "peak_views"
      type = "bigint"
    }
    columns {
      name = "times_trending"
      type = "bigint"
    }
    columns {
      name = "first_trending"
      type = "date"
    }
    columns {
      name = "last_trending"
      type = "date"
    }
    columns {
      name = "categories"
      type = "array<string>"
    }
    columns {
      name = "rank_in_region"
      type = "int"
    }
    columns {
      name = "_aggregated_at"
      type = "timestamp"
    }
  }
  partition_keys {
    name = "region"
    type = "string"
  }

  parameters = {
    "classification" = "parquet"
  }

  lifecycle {
    ignore_changes = [
      parameters,
    ]
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
      name = "trending_date_parsed"
      type = "date"
    }
    columns {
      name = "total_videos"
      type = "bigint"
    }
    columns {
      name = "total_views"
      type = "bigint"
    }
    columns {
      name = "total_likes"
      type = "bigint"
    }
    columns {
      name = "total_dislikes"
      type = "bigint"
    }
    columns {
      name = "total_comments"
      type = "bigint"
    }
    columns {
      name = "avg_views_per_video"
      type = "double"
    }
    columns {
      name = "avg_like_ratio"
      type = "double"
    }
    columns {
      name = "avg_engagement_rate"
      type = "double"
    }
    columns {
      name = "max_views"
      type = "bigint"
    }
    columns {
      name = "unique_channels"
      type = "bigint"
    }
    columns {
      name = "unique_categories"
      type = "bigint"
    }
    columns {
      name = "_aggregated_at"
      type = "timestamp"
    }
  }

  partition_keys {
    name = "region"
    type = "string"
  }

  parameters = {
    "classification" = "parquet"
  }
  lifecycle {
    ignore_changes = [
      parameters,
    ]
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
# Glue Table Partitions
# ────────────────────────────────────────────────────────────────────────────

locals {
  all_regions   = ["ca", "de", "fr", "gb", "in", "jp", "kr", "mx", "ru", "us"]
  gold_regions  = ["ca", "gb", "in", "us"]
  bronze_bucket = "rid-yt-pipeline-bronze-${var.aws_region}-${var.environment_name}-v2"
  silver_bucket = "rid-yt-pipeline-silver-${var.aws_region}-${var.environment_name}-v2"
  gold_bucket   = "rid-yt-pipeline-gold-${var.aws_region}-${var.environment_name}-v2"
  bronze_partition_sd = {
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    serde         = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
  }
  parquet_partition_sd = {
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    serde         = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
  }
}

# ── Bronze — raw_statistics ──
resource "aws_glue_partition" "bronze_raw_statistics" {
  for_each = toset(local.all_regions)

  database_name    = aws_glue_catalog_database.bronze.name
  table_name       = aws_glue_catalog_table.bronze_raw_statistics.name
  partition_values = [each.value]

  storage_descriptor {
    location      = "s3://${local.bronze_bucket}/youtube/raw_statistics/region=${each.value}/"
    input_format  = local.bronze_partition_sd.input_format
    output_format = local.bronze_partition_sd.output_format
    ser_de_info {
      serialization_library = local.bronze_partition_sd.serde
    }
  }
}

# ── Bronze — raw_statistics_reference_data ──
resource "aws_glue_partition" "bronze_reference_data" {
  for_each = toset(local.all_regions)

  database_name    = aws_glue_catalog_database.bronze.name
  table_name       = aws_glue_catalog_table.bronze_reference_data.name
  partition_values = [each.value]

  storage_descriptor {
    location      = "s3://${local.bronze_bucket}/youtube/raw_statistics_reference_data/region=${each.value}/"
    input_format  = local.bronze_partition_sd.input_format
    output_format = local.bronze_partition_sd.output_format
    ser_de_info {
      serialization_library = local.bronze_partition_sd.serde
    }
  }
}

# ── Silver — clean_statistics ──
resource "aws_glue_partition" "silver_clean_statistics" {
  for_each = toset(local.all_regions)

  database_name    = aws_glue_catalog_database.silver.name
  table_name       = aws_glue_catalog_table.silver_clean_statistics.name
  partition_values = [each.value]

  storage_descriptor {
    location      = "s3://${local.silver_bucket}/youtube/statistics/region=${each.value}/"
    input_format  = local.parquet_partition_sd.input_format
    output_format = local.parquet_partition_sd.output_format
    ser_de_info {
      serialization_library = local.parquet_partition_sd.serde
    }
  }
}

# ── Silver — clean_reference_data ──
resource "aws_glue_partition" "silver_reference_data" {
  for_each = toset(local.all_regions)

  database_name    = aws_glue_catalog_database.silver.name
  table_name       = aws_glue_catalog_table.silver_reference_data.name
  partition_values = [each.value]

  storage_descriptor {
    location      = "s3://${local.silver_bucket}/youtube/reference_data/region=${each.value}/"
    input_format  = local.parquet_partition_sd.input_format
    output_format = local.parquet_partition_sd.output_format
    ser_de_info {
      serialization_library = local.parquet_partition_sd.serde
    }
  }
}

# ── Gold — category_analytics ──
resource "aws_glue_partition" "gold_category_analytics" {
  for_each = toset(local.gold_regions)

  database_name    = aws_glue_catalog_database.gold.name
  table_name       = aws_glue_catalog_table.gold_category_analytics.name
  partition_values = [each.value]

  storage_descriptor {
    location      = "s3://${local.gold_bucket}/youtube/category_analytics/region=${each.value}/"
    input_format  = local.parquet_partition_sd.input_format
    output_format = local.parquet_partition_sd.output_format
    ser_de_info {
      serialization_library = local.parquet_partition_sd.serde
    }
  }
}

# ── Gold — channel_analytics ──
resource "aws_glue_partition" "gold_channel_analytics" {
  for_each = toset(local.gold_regions)

  database_name    = aws_glue_catalog_database.gold.name
  table_name       = aws_glue_catalog_table.gold_channel_analytics.name
  partition_values = [each.value]

  storage_descriptor {
    location      = "s3://${local.gold_bucket}/youtube/channel_analytics/region=${each.value}/"
    input_format  = local.parquet_partition_sd.input_format
    output_format = local.parquet_partition_sd.output_format
    ser_de_info {
      serialization_library = local.parquet_partition_sd.serde
    }
  }
}

# ── Gold — trending_analytics ──
resource "aws_glue_partition" "gold_trending_analytics" {
  for_each = toset(local.gold_regions)

  database_name    = aws_glue_catalog_database.gold.name
  table_name       = aws_glue_catalog_table.gold_trending_analytics.name
  partition_values = [each.value]

  storage_descriptor {
    location      = "s3://${local.gold_bucket}/youtube/trending_analytics/region=${each.value}/"
    input_format  = local.parquet_partition_sd.input_format
    output_format = local.parquet_partition_sd.output_format
    ser_de_info {
      serialization_library = local.parquet_partition_sd.serde
    }
  }
}

# ────────────────────────────────────────────────────────────────────────────
# Data Outputs
# ────────────────────────────────────────────────────────────────────────────

# Note: These outputs are for reference. The actual backend configuration
# lives in root terraform/backend.tf
