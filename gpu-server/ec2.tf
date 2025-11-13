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

  # Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.7 (Ubuntu 22.04) 20250602
  #ami = "ami-05ee60afff9d0a480"  # us-east-1
  #ami = "ami-0f7e62cd1dcdf9b34"  # ap-northeast-1
  ami = var.ami # Example AMI ID for Ubuntu 22.04 LTS

  # The EC2 instance type.
  #instance_type = "p4d.24xlarge" # Eight A100 GPUs, 96 vCPUs, 1152 GiB RAM
  instance_type = var.instance_type # 1 CPU

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


  # Configure root volume
  root_block_device {
    volume_type           = "gp3" # Use gp3 for improved performance and cost control
    volume_size           = 300   # 300 GiB
    iops                  = 3000  # Provisioned IOPS (default for gp3 is 3000)
    encrypted             = false # Set to false for unencrypted volume (default is false)
    delete_on_termination = true  # Deletes the volume when the instance is terminated
  }



  capacity_reservation_specification {
    capacity_reservation_target {
      capacity_reservation_id = var.capacity_reservation_id
    }
  }


  depends_on = [
    aws_subnet.public,
    aws_security_group.ssh_access
  ]

}
