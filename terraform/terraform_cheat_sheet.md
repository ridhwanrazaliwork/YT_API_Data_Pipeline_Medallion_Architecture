# Initialize (download providers)
terraform init

# Validate syntax
terraform validate

# Format code (cleanup)
terraform fmt -recursive

# Plan (preview changes)
terraform plan

# Plan to file (to review before apply)
terraform plan -out=my.tfplan

# Apply from file (safer than direct apply)
terraform apply my.tfplan

# Apply with approval (asks yes/no)
terraform apply

# Apply specific module
terraform apply -target=module.networking

# See outputs
terraform output

# See specific output
terraform output vpc_id

# Remove all (destroy)
terraform destroy

# Check current state
terraform state list
terraform state show module.networking.aws_vpc.main