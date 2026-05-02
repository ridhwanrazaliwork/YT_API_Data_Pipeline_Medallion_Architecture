# This file configures Terraform's remote state backend for team collaboration.
#
# INITIAL SETUP:
# 1. Create S3 bucket: aws s3 mb s3://yt-pipeline-terraform-state-ap-southeast-1 --region ap-southeast-1
# 2. Enable versioning: aws s3api put-bucket-versioning --bucket yt-pipeline-terraform-state-ap-southeast-1 --versioning-configuration Status=Enabled
# 3. Create DynamoDB table: aws dynamodb create-table --table-name terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region ap-southeast-1
# 4. Uncomment the backend block below
# 5. Run: terraform init
#
# SECURITY:
# - Enable encryption on S3 bucket: aws s3api put-bucket-encryption --bucket yt-pipeline-terraform-state-ap-southeast-1 --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
# - Block public access: aws s3api put-public-access-block --bucket yt-pipeline-terraform-state-ap-southeast-1 --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
#
# TROUBLESHOOTING:
# If you get "Error acquiring the state lock", check DynamoDB table exists and Lambda has permissions

terraform {
  backend "s3" {
    bucket         = "yt-pipeline-terraform-state-ap-southeast-1-v2"
    key            = "youtube-pipeline/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-v2"
  }
}
