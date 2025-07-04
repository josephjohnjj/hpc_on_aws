# -----------------------------------
# Output: EC2 Instance ID
# -----------------------------------
output "instance_id" {
  # Description to document what this output represents
  description = "ID of the EC2 instance"

  # The actual value to output: the unique ID of the EC2 instance created
  value = aws_instance.GpuTrainingServer.id
}

# -----------------------------------
# Output: EC2 Instance Public IP
# -----------------------------------
output "instance_public_ip" {
  # Description of the output value
  description = "Public IP address of the EC2 instance"

  # The value to output: the public IP assigned to the instance
  value = aws_instance.GpuTrainingServer.public_ip
}
