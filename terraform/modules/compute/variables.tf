variable "environment_name" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Lambda deployment"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for Lambda deployment"
  type        = string
}

variable "sg_ingestion_id" {
  description = "Security group ID for ingestion Lambda"
  type        = string
}

variable "sg_quality_id" {
  description = "Security group ID for quality Lambda"
  type        = string
}

variable "lambda_timeout_seconds" {
  description = "Lambda function timeout"
  type        = number
  default     = 60
}

variable "lambda_memory_mb" {
  description = "Lambda function memory"
  type        = number
  default     = 256
}
