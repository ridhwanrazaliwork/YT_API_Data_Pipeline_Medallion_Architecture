/*
Development Environment Configuration
──────────────────────────────────────

This calls the root modules with dev-specific variables.
*/

# ────────────────
# Ridhwan Study Notes
#
# What is 'var'? 
#   - 'var' is used in Terraform to reference input variables. 
# These variables are defined in a variables.tf file or passed in via terraform.tfvars or the CLI. 
# For example, 'var.environment_name' gets the value of the 'environment_name' variable for this environment.
#
# What is 'module'? 
#   - 'module' in Terraform is a container for multiple resources that are used together. 
# Here, 'module "youtube_pipeline"' calls a reusable set of Terraform code (the root module) and passes in environment-specific variables. 
# This helps organize and reuse infrastructure code.
#
# (End Ridhwan Study Notes)

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
    # lambda_role          = module.youtube_pipeline.lambda_role_arn
    # terraform_state      = module.youtube_pipeline.terraform_state_bucket_name
  }
}