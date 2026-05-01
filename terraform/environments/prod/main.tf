/*
Production Environment Configuration
────────────────────────────────────

This calls the root modules with prod-specific variables.
Prod should have higher timeouts and memory than dev. 
and should have different VPC CIDR and subnet CIDR to avoid conflicts 
if both environments are deployed at the same time.
*/

# NOTE for study:
# In real-world scenarios, you should use different variables (var values) for each environment (dev, prod, etc.) to reflect their unique configurations.
# Here, the variables and module usage are the same for both dev and prod because this setup is for learning purposes.
# Adjust variables as needed when moving to production.

module "youtube_pipeline" {
  source = "../../"

  # From terraform.tfvars
  environment_name        = var.environment_name
  aws_region              = var.aws_region
  vpc_cidr                = var.vpc_cidr
  public_subnet_cidr      = var.public_subnet_cidr
  lambda_timeout_seconds  = var.lambda_timeout_seconds
  lambda_memory_mb        = var.lambda_memory_mb
}

# Output all root outputs for convenience
output "deployment_summary" {
  value = {
    environment          = module.youtube_pipeline.deployment_summary.environment
    region               = module.youtube_pipeline.deployment_summary.region
    vpc_id               = module.youtube_pipeline.vpc_id
    public_subnet_id     = module.youtube_pipeline.public_subnet_id
    security_groups      = {
      ingestion = module.youtube_pipeline.sg_ingestion_id
      quality   = module.youtube_pipeline.sg_quality_id
    }
    lambda_role          = module.youtube_pipeline.lambda_role_arn
    terraform_state      = module.youtube_pipeline.terraform_state_bucket_name
  }
}
