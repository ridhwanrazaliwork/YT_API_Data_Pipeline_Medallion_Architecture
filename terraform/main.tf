terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # State backend configured in backend.tf
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment_name
      Project     = "youtube-pipeline"
      ManagedBy   = "Terraform"
    }
  }
}

# Networking module — VPC, subnets, Internet Gateway, security groups
module "networking" {
  source = "./modules/networking"
  environment_name = var.environment_name
  vpc_cidr         = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  aws_region       = var.aws_region
}

# Compute module — IAM roles, Lambda specs, Secrets Manager
module "compute" {
  source = "./modules/compute"
  environment_name      = var.environment_name
  aws_region            = var.aws_region
  vpc_id                = module.networking.vpc_id
  public_subnet_id      = module.networking.public_subnet_id
  sg_ingestion_id       = module.networking.sg_ingestion_id
  sg_quality_id         = module.networking.sg_quality_id
  depends_on = [module.networking]
}

# Data module — S3 state bucket, DynamoDB locks (for team collaboration)
module "data" {
  source = "./modules/data"

  environment_name = var.environment_name
  aws_region       = var.aws_region

  depends_on = [module.networking, module.compute]
}

# Output key values for reference
locals {
  outputs_summary = {
    vpc_id                = module.networking.vpc_id
    public_subnet_id      = module.networking.public_subnet_id
    sg_ingestion_id       = module.networking.sg_ingestion_id
    sg_quality_id         = module.networking.sg_quality_id
    lambda_role_arn       = module.compute.lambda_role_arn
    terraform_state_bucket = module.data.state_bucket_name
    terraform_locks_table = module.data.locks_table_name
  }
}
