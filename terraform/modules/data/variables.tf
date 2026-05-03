variable "environment_name" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "transform_lambda_arn" {
  description = "ARN of Transform Lambda function for S3 event notification"
  type        = string
  default     = ""
}
