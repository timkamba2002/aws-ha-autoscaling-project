resource "aws_vpc" "main" {
  count = var.create ? 1 : 0

  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "ha-project-vpc"
  }
}

resource "aws_subnet" "public_a" {
  count = var.create ? 1 : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  count = var.create ? 1 : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-b"
  }
}

resource "aws_subnet" "private_a" {
  count = var.create ? 1 : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  count = var.create ? 1 : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet-b"
  }
}

resource "aws_internet_gateway" "igw" {
  count = var.create ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "ha-project-igw"
  }
}

resource "aws_route_table" "public" {
  count = var.create ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_a" {
  count = var.create ? 1 : 0

  subnet_id      = aws_subnet.public_a[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "public_b" {
  count = var.create ? 1 : 0

  subnet_id      = aws_subnet.public_b[0].id
  route_table_id = aws_route_table.public[0].id
}

# Allocate Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  count = var.create ? 1 : 0

  domain = "vpc"
}

# NAT Gateway in public subnet A
resource "aws_nat_gateway" "nat_gw" {
  count = var.create ? 1 : 0

  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = aws_subnet.public_a[0].id

  tags = {
    Name = "ha-project-nat-gateway"
  }
}

# Private route table
resource "aws_route_table" "private_rt" {
  count = var.create ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "ha-project-private-rt"
  }
}

# Route private traffic → NAT Gateway
resource "aws_route" "private_nat_route" {
  count = var.create ? 1 : 0

  route_table_id         = aws_route_table.private_rt[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[0].id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private_a" {
  count = var.create ? 1 : 0

  subnet_id      = aws_subnet.private_a[0].id
  route_table_id = aws_route_table.private_rt[0].id
}

resource "aws_route_table_association" "private_b" {
  count = var.create ? 1 : 0

  subnet_id      = aws_subnet.private_b[0].id
  route_table_id = aws_route_table.private_rt[0].id
}

# Data sources for lookup when create=false (staging/prod reuse the resources created by development state)
data "aws_vpc" "main" {
  count = var.create ? 0 : 1
  id    = var.vpc_id != "" ? var.vpc_id : "vpc-0d4035555d90998ca"
}

data "aws_subnet" "public_a" {
  count  = var.create ? 0 : 1
  vpc_id = data.aws_vpc.main[0].id
  tags = {
    Name = "public-subnet-a"
  }
}

data "aws_subnet" "public_b" {
  count  = var.create ? 0 : 1
  vpc_id = data.aws_vpc.main[0].id
  tags = {
    Name = "public-subnet-b"
  }
}

data "aws_subnet" "private_a" {
  count  = var.create ? 0 : 1
  vpc_id = data.aws_vpc.main[0].id
  tags = {
    Name = "private-subnet-a"
  }
}

data "aws_subnet" "private_b" {
  count  = var.create ? 0 : 1
  vpc_id = data.aws_vpc.main[0].id
  tags = {
    Name = "private-subnet-b"
  }
}

data "aws_internet_gateway" "main" {
  count = var.create ? 0 : 1
  filter {
    name   = "tag:Name"
    values = ["ha-project-igw"]
  }
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.main[0].id]
  }
}

data "aws_nat_gateway" "main" {
  count = var.create ? 0 : 1
  filter {
    name   = "tag:Name"
    values = ["ha-project-nat-gateway"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main[0].id]
  }
}
