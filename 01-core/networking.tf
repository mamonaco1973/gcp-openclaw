# ================================================================================
# FILE: network.tf
# ================================================================================
#
# Purpose:
#   Define baseline networking for the OpenClaw environment, including:
#     - VPC with DNS support and hostnames enabled
#     - Public subnets for NAT gateway placement
#     - Private subnets for EC2 workload hosts (egress via NAT)
#     - Internet Gateway for public subnet egress
#     - NAT Gateway for private subnet outbound access
#     - Route tables (public/private) and subnet associations
#
# Notes:
#   - All subnets have map_public_ip_on_launch = true, but vm-subnets route
#     through the NAT gateway — instances receive public IPs that are not
#     reachable inbound due to no IGW route on the private route table.
#   - VPC CIDR: 10.0.0.0/23, region: us-east-1
#
# ================================================================================


# ================================================================================
# SECTION: VPC
# ================================================================================

# VPC with DNS support and hostnames enabled for EC2 instance name resolution.
resource "aws_vpc" "clawd-vpc" {
  cidr_block           = "10.0.0.0/23"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.vpc_name }
}


# ================================================================================
# SECTION: Internet Gateway
# ================================================================================

# Internet Gateway provides egress for public subnets and NAT gateway traffic.
resource "aws_internet_gateway" "clawd-igw" {
  vpc_id = aws_vpc.clawd-vpc.id
  tags   = { Name = "clawd-igw" }
}


# ================================================================================
# SECTION: Subnets
# ================================================================================

# Subnet layout:
#   - vm-subnet-1: 10.0.0.64/26, workload hosts (private routing), AZ use1-az6
#   - vm-subnet-2: 10.0.0.128/26, workload hosts (private routing), AZ use1-az4
#   - pub-subnet-1: 10.0.0.192/26, NAT gateway placement (public), AZ use1-az4
#   - pub-subnet-2: 10.0.1.0/26, NAT gateway placement (public), AZ use1-az6

resource "aws_subnet" "vm-subnet-1" {
  vpc_id                  = aws_vpc.clawd-vpc.id
  cidr_block              = "10.0.0.64/26"
  map_public_ip_on_launch = true
  availability_zone_id    = "use1-az6"

  tags = { Name = "vm-subnet-1" }
}

resource "aws_subnet" "vm-subnet-2" {
  vpc_id                  = aws_vpc.clawd-vpc.id
  cidr_block              = "10.0.0.128/26"
  map_public_ip_on_launch = true
  availability_zone_id    = "use1-az4"

  tags = { Name = "vm-subnet-2" }
}

resource "aws_subnet" "pub-subnet-1" {
  vpc_id                  = aws_vpc.clawd-vpc.id
  cidr_block              = "10.0.0.192/26"
  map_public_ip_on_launch = true
  availability_zone_id    = "use1-az4"

  tags = { Name = "pub-subnet-1" }
}

resource "aws_subnet" "pub-subnet-2" {
  vpc_id                  = aws_vpc.clawd-vpc.id
  cidr_block              = "10.0.1.0/26"
  map_public_ip_on_launch = true
  availability_zone_id    = "use1-az6"

  tags = { Name = "pub-subnet-2" }
}


# ================================================================================
# SECTION: NAT Elastic IP
# ================================================================================

# Elastic IP provides a stable public egress address for the NAT gateway.
resource "aws_eip" "nat_eip" {
  tags = { Name = "nat-eip" }
}


# ================================================================================
# SECTION: NAT Gateway
# ================================================================================

# NAT gateway is placed in a public subnet to provide outbound internet access
# for private subnets without inbound internet exposure.
resource "aws_nat_gateway" "clawd_nat" {
  subnet_id     = aws_subnet.pub-subnet-1.id
  allocation_id = aws_eip.nat_eip.id
  tags          = { Name = "clawd-nat" }
}


# ================================================================================
# SECTION: Route Tables and Routes
# ================================================================================

# Public route table: default route to Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.clawd-vpc.id
  tags   = { Name = "public-route-table" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.clawd-igw.id
}

# Private route table: default route to NAT gateway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.clawd-vpc.id
  tags   = { Name = "private-route-table" }
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.clawd_nat.id
}


# ================================================================================
# SECTION: Route Table Associations
# ================================================================================

# Associate private route table with vm-subnets; outbound traffic routes via NAT.
resource "aws_route_table_association" "rt_assoc_vm_public" {
  subnet_id      = aws_subnet.vm-subnet-1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "rt_assoc_vm_public_2" {
  subnet_id      = aws_subnet.vm-subnet-2.id
  route_table_id = aws_route_table.private.id
}

# Associate public route table with public subnets (egress via IGW).
resource "aws_route_table_association" "rt_assoc_pub_public" {
  subnet_id      = aws_subnet.pub-subnet-1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "rt_assoc_pub_public_2" {
  subnet_id      = aws_subnet.pub-subnet-2.id
  route_table_id = aws_route_table.public.id
}
