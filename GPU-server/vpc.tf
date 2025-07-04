# -----------------------------------------------------
# Create a Virtual Private Cloud (VPC)
# -----------------------------------------------------
resource "aws_vpc" "main" {
  # The CIDR block defines the private IP address range for the VPC
  # 10.0.0.0/16 allows for 65,536 IP addresses
  cidr_block = "10.0.0.0/16"

  # Enables internal DNS resolution within the VPC (useful for instance names, etc.)
  enable_dns_support = true

  # Ensures that instances launched in this VPC receive DNS hostnames
  # Required for public EC2 instances that should be reachable by DNS
  enable_dns_hostnames = true

  # Add a tag to easily identify this VPC in the AWS Console
  tags = {
    Name = "GPU-Server-main-vpc"
  }
}

# -----------------------------------------------------
# Attach an Internet Gateway to the VPC
# -----------------------------------------------------
resource "aws_internet_gateway" "main" {
  # Link the gateway to the above VPC
  vpc_id = aws_vpc.main.id

  # Tag the internet gateway for identification
  tags = {
    Name = "GPU-Server-main-gateway"
  }
}

# -----------------------------------------------------
# Create a Public Subnet
# -----------------------------------------------------
resource "aws_subnet" "public" {
  # Associate this subnet with the main VPC
  vpc_id = aws_vpc.main.id

  # Define a smaller address block inside the VPC's range
  # 10.0.1.0/24 supports 256 IP addresses (usable: 251)
  cidr_block = "10.0.1.0/24"

  # Automatically assign a public IP address to EC2 instances at launch
  # Required for them to be reachable from the internet
  map_public_ip_on_launch = true

  # Tag for easier identification in the console
  tags = {
    Name = "GPU-Server-public-subnet"
  }
}

# -----------------------------------------------------
# Create a Route Table for Public Subnet
# -----------------------------------------------------
resource "aws_route_table" "public" {
  # Attach this route table to the main VPC
  vpc_id = aws_vpc.main.id

  # Define a default route (0.0.0.0/0) that sends all internet-bound traffic
  # through the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  # Tag for visibility in the AWS Console
  tags = {
    Name = "GPU-Server-public-route-table"
  }
}

# -----------------------------------------------------
# Associate the Public Subnet with the Public Route Table
# -----------------------------------------------------
resource "aws_route_table_association" "public_assoc" {
  # Link the public subnet to the route table
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
