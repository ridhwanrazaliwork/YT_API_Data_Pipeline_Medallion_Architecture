variable "environment_name" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout"
  type        = number
}

variable "lambda_memory_mb" {
  description = "Lambda memory"
  type        = number
}
