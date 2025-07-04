# ---------------------------
# Create an AWS Key Pair
# ---------------------------
resource "aws_key_pair" "hcp_key" {
  # The name of the key pair to create in AWS
  key_name = "terraform-user"

  # The public key file to register with AWS
  # This file should exist at keys/terraform-user.pub relative to the module path
  public_key = file("${path.module}/keys/terraform-user.pub")
}

# ---------------------------
# Launch an EC2 Instance
# ---------------------------
resource "aws_instance" "GpuTrainingServer" {
  # The AMI ID for the EC2 instance.
  # This AMI must exist in your selected region.
  #ami = "ami-05ee60afff9d0a480"  # Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.7 (Ubuntu 22.04) 20250602
  ami = "ami-020cba7c55df1f615" # Example AMI ID for Ubuntu 22.04 LTS

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = "t2.micro" # 1 CPU

  # Use the key pair created above for SSH access.
  key_name = aws_key_pair.hcp_key.key_name

  # ID of the subnet to launch the instance in.
  # This subnet must exist and be public for public IP assignment to work.
  subnet_id = aws_subnet.public.id

  # Attach one or more security groups to the instance.
  # This should include rules to allow SSH (port 22) access.
  vpc_security_group_ids = [aws_security_group.ssh_access.id]

  # Ensure the instance gets a public IP address.
  # Required for SSH access from the internet.
  associate_public_ip_address = true

  # Add tags to the instance for identification and management.
  tags = {
    Name = "NCI-GPU-Server" # Name tag appears in the EC2 console
  }

  # Conditionally specify Capacity Reservation for this instance
  # If 'capacity_reservation_id' variable is non-empty, the instance
  # will launch into the specified Capacity Reservation block.
  dynamic "capacity_reservation_specification" {
    for_each = var.capacity_reservation_id != "" ? [1] : []

    content {
      capacity_reservation_target {
        capacity_reservation_id = var.capacity_reservation_id
      }
    }
  }

}
