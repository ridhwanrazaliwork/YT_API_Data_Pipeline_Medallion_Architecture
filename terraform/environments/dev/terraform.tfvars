# Development Environment Variables
# ──────────────────────────────────

# Networking Study Note:
# CIDR (Classless Inter-Domain Routing) notation defines IP address ranges.
# Example: '10.0.0.0/16' means:
#   - '10.0.0.0' is the network address.
#   - '/16' means the first 16 bits are the network part, leaving 16 bits for hosts.
#   - This allows for 2^(32-16) = 65,536 possible IP addresses in this range.
#   - The subnet '10.0.1.0/24' means 256 addresses (2^(32-24)).
# CIDR is used to control how many devices (clients/servers) can be addressed in the network.

environment_name       = "dev"
aws_region             = "ap-southeast-1"
vpc_cidr               = "10.0.0.0/16"
public_subnet_cidr     = "10.0.1.0/24"
lambda_timeout_seconds = 120
lambda_memory_mb       = 512

