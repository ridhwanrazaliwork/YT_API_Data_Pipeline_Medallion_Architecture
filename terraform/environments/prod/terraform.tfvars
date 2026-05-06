# Production Environment Variables
# ─────────────────────────────────

environment_name       = "prod"
aws_region             = "ap-southeast-1"
vpc_cidr               = "10.0.0.0/16"
public_subnet_cidr     = "10.0.1.0/24"
lambda_timeout_seconds = 120 # Higher timeout for prod
lambda_memory_mb       = 512 # Higher memory for prod