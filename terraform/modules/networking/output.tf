output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "sg_ingestion_id" {
  description = "Security group ID for ingestion Lambda"
  value       = aws_security_group.ingestion.id
}

output "sg_quality_id" {
  description = "Security group ID for quality Lambda"
  value       = aws_security_group.quality.id
}

