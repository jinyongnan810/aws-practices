# Create a VPC and two subnets (one public, one private) in AWS.
# 1. Create the VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16" # Provides up to 65,536 IP addresses
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Production-VPC"
  }
}

# 2. Create the Internet Gateway (The door to the outside world)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Production-IGW"
  }
}

# 3. Create a Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24" # 256 IPs
  map_public_ip_on_launch = true          # Automatically assigns public IPs to instances here

  tags = {
    Name = "Public-Subnet-1"
  }
}

# 3b. Create a second Public Subnet in a DIFFERENT AZ (ALB requires >= 2 AZs)
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-2"
  }
}

# 4. Create a Route Table for the Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  # This route directs all outbound traffic (0.0.0.0/0) to the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# 5. Associate the Route Table with both Public Subnets
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 6. Create a Private Subnet (No route to the IGW!)
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "Private-Subnet-1"
  }
}

# 7. Create a second Private Subnet in a DIFFERENT Availability Zone
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"     # A new, non-overlapping IP range
  availability_zone = "ap-northeast-1c" # Forcing it into a different AZ

  tags = {
    Name = "Private-Subnet-2"
  }
}

# 8. Elastic IP for the NAT Gateway (a static public IP)
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "Production-NAT-EIP"
  }
}

# 9. NAT Gateway (lives in the PUBLIC subnet so private subnets can reach the internet)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "Production-NAT"
  }

  # Ensure the IGW exists before the NAT Gateway
  depends_on = [aws_internet_gateway.igw]
}

# 10. Private Route Table (routes outbound traffic through the NAT Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private-RT"
  }
}

# 11. Associate the Private Route Table with both Private Subnets
resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}