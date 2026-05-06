
# ────────────────
# Ridhwan Networking Study Notes
#

# Common Networking Jargon & AWS Tools:
#
# • TCP (Transmission Control Protocol):
#   - Reliable, connection-based protocol. Data is delivered in order and checked for errors.
#   - Used for web (HTTP/HTTPS), SSH, database connections, etc.
#   - Example: Loading a website or transferring files.
#
# • UDP (User Datagram Protocol):
#   - Fast, connectionless protocol. No guarantee of delivery or order.
#   - Used for DNS, video streaming, gaming, VoIP.
#   - Example: Watching a live stream (some data loss is okay for speed).
#
# • Port:
#   - Number identifying a specific process/service on a server.
#   - Common ports: 80=HTTP, 443=HTTPS, 22=SSH, 53=DNS.
#
# • Ingress:
#   - Incoming network traffic (e.g., user requests to your server).
#
# • Egress:
#   - Outgoing network traffic (e.g., your server calling an external API).
#
# • CIDR (Classless Inter-Domain Routing):
#   - Notation for IP address ranges. Example: 0.0.0.0/0 means "all IPs can access" (open to the world).
#   - For better security, restrict to your office/home IP (e.g., 203.0.113.0/24) or VPN IP range instead of 0.0.0.0/0.
#
# • 0.0.0.0/0:
#   - Represents all IPv4 addresses (anyone on the internet). Use only for public resources or testing.
#   - For production, always restrict to known IPs when possible.
#
# • Subnet:
#   - A segment of a VPC's IP range. Can be public (internet-facing) or private (internal only).
#   - Example: Public subnet for web servers, private subnet for databases.
#
# • Security Group:
#   - Acts as a virtual firewall for EC2, Lambda, etc.
#   - Controls allowed ingress (inbound) and egress (outbound) traffic by port, protocol, and IP.
#   - Example: Allow inbound TCP 22 (SSH) only from your office IP, allow outbound TCP 443 (HTTPS) to anywhere.
#   - Security groups are stateful: if you allow incoming traffic, the response is automatically allowed out.
#   - Example rule:
#       Ingress: TCP, port 22, source 203.0.113.0/24 (only your office can SSH)
#       Egress: TCP, port 443, destination 0.0.0.0/0 (can access any HTTPS site)
#
# For this project, using 0.0.0.0/0 for outbound (egress) rules is acceptable because we need to access public APIs (like YouTube) and DNS servers, whose IPs are not fixed.
# However, for inbound (ingress) rules or for other sensitive tools, always use specific IP addresses or ranges to improve security.
#
# • Private DNS:
#   - DNS names that resolve only within your VPC (e.g., for private endpoints or internal services).
#
# • VPC Endpoint:
#   - Lets you privately connect your VPC to AWS services (like S3, Secrets Manager) without using the internet.
#   - Example: Lambda in a private subnet can access S3 via a VPC endpoint, even with no internet gateway.
#
# • Route Table:
#   - Set of rules that determine where network traffic is directed within your VPC/subnets.
#   - Example: Public subnet route table sends 0.0.0.0/0 to the internet gateway; private subnet route table sends 0.0.0.0/0 to a NAT gateway or nowhere (fully private).
#
# • Secret Manager Endpoint:
#   - A VPC endpoint for AWS Secrets Manager, so you can access secrets privately from your VPC.
#
# Why use these?
# - Control who/what can access your resources (security).
# - Keep sensitive data private (no public internet exposure).
# - Meet compliance requirements.
#
# (End Ridhwan Networking Study Notes)
/* 
Networking Module: VPC, Public Subnet, Internet Gateway, Security Groups
──────────────────────────────────────────────────────────────────────────

CURRENT APPROACH: LOWEST COST
- Public subnets only (no VPC endpoints)
- All Lambdas access AWS services via Internet Gateway
- Cost: Minimal (~$0 extra, just data transfer ~$0.02/GB)
- Trade-off: Less secure than best practice

BEST PRACTICE (for production): Use private subnets + S3 VPC endpoint
- Private subnets across 2+ AZs
- S3 Gateway Endpoint (free, better security)
- Cost: ~$7-15/month
- Better: High availability, better security

*/

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment_name}-vpc"
  }
  lifecycle {
    ignore_changes = [tags_all]
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment_name}-igw"
  }
  lifecycle {
    ignore_changes = [tags_all]
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.environment_name}-public-subnet"
  }
  lifecycle {
    ignore_changes = [tags_all]
  }
}

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Route table: public subnet → Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.environment_name}-public-rt"
  }
  lifecycle {
    ignore_changes = [tags_all]
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

/* 
Security Group: Ingestion Lambda (YouTube API)
─────────────────────────────────────────────

Purpose: Allow Ingestion Lambda to call YouTube API

Outbound:
  - HTTPS 443 to YouTube API (0.0.0.0/0)
  - DNS 53 for DNS resolution
*/
resource "aws_security_group" "ingestion" {
  name        = "${var.environment_name}-sg-ingestion"
  description = "Security group for YouTube API ingestion Lambda"
  vpc_id      = aws_vpc.main.id


  # Outbound: HTTPS to YouTube API
  egress {
    description = "HTTPS to YouTube API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound: DNS (required for API calls)
  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment_name}-sg-ingestion"
  }
  lifecycle {
    ignore_changes = [tags_all]
  }
}

/* 
Security Group: Quality Lambda (S3/Athena access only)
──────────────────────────────────────────────────────

Purpose: Allow Quality Lambda to access S3 and Athena

No external API calls, so only DNS egress needed.
S3/Athena access goes via Internet Gateway (public subnet).

Outbound:
  - DNS 53 for DNS resolution
*/
resource "aws_security_group" "quality" {
  name        = "${var.environment_name}-sg-quality"
  description = "Security group for data quality Lambda (S3/Athena access)"
  vpc_id      = aws_vpc.main.id

  # Outbound: DNS (required for S3/Athena calls)
  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS to AWS services (Athena, S3, Glue)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment_name}-sg-quality"
  }
}