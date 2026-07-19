# Set up NAT Gateway for Private Subnet to access the Internet via the Public Subnet
# 1. Allocate an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "Production-NAT-EIP"
  }
}

# 2. Create the NAT Gateway (Must live in the PUBLIC subnet!)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id # Placing it in the public subnet

  tags = {
    Name = "Production-NAT-GW"
  }

  # Best Practice: Ensure the IGW exists before creating a NAT Gateway
  depends_on = [aws_internet_gateway.igw]
}

# 3. Create a Route Table specifically for the Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  # Direct all outbound traffic to the NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "Private-Route-Table"
  }
}

# 4. Associate the Route Table with the Private Subnet
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}