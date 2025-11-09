# -----------------------------------------------------
# Security Group: Allow SSH Access from Anywhere
# -----------------------------------------------------
resource "aws_security_group" "ssh_access" {
  # The name of the security group (visible in AWS Console)
  name = "allow_ssh_from_anywhere"

  # A short description for documentation
  description = "Allow SSH inbound traffic"

  # The ID of the VPC where this security group will be created
  vpc_id = aws_vpc.main.id

  # -----------------------------
  # Ingress Rule 1: IPv4 SSH Access
  # -----------------------------
  ingress {
    # Rule description shown in AWS Console
    description = "SSH from anywhere (IPv4)"

    # SSH uses TCP port 22, so allow traffic on port 22
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    # Allow incoming SSH connections from any IPv4 address
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------
  # Ingress Rule 2: IPv6 SSH Access
  # -----------------------------
  ingress {
    # Same as above, but for IPv6
    description = "SSH from anywhere (IPv6)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    # Allow incoming SSH connections from any IPv6 address
    ipv6_cidr_blocks = ["::/0"]
  }

  # -----------------------------
  # Egress Rule: Allow All Outbound Traffic
  # -----------------------------
  egress {
    # Allow all types of outbound traffic (all protocols and ports)
    from_port = 0
    to_port   = 0

    # "-1" means "all protocols"
    protocol = "-1"

    # Allow outgoing traffic to any IPv4 address
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------
  # Tag for Easy Identification
  # -----------------------------
  tags = {
    Name = "GPU-Server-ssh-access" # This tag shows up in AWS Console
  }
}
