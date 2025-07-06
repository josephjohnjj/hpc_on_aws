resource "random_password" "user_pw" {
  length           = 16
  override_special = "!@#$%&*()-_+="
}

// Import the SSH key pair for initial access
resource "aws_key_pair" "hcp_key" {
  key_name   = "terraform-user"
  public_key = file("${path.module}/keys/terraform-user.pub")
}


resource "aws_instance" "app_server" {
  ami                         = "ami-020cba7c55df1f615"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.hcp_key.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ssh_access.id]
  associate_public_ip_address = true

// set user pw
  user_data = <<-EOF
    #cloud-config
    ssh_pwauth: true
    users:
      - name: user
        gecos: "User"
        sudo: ALL=(ALL) NOPASSWD:ALL
        lock_passwd: false
    chpasswd:
      list: |
        user:${random_password.user_pw.result}
      expire: false
  EOF

  tags = {
    Name = "gpu-ssh-server"
  }
}

// Expose the generated password as a sensitive output for secure delivery
output "user_password" {
  value       = random_password.user_pw.result
  description = "Password for the user on the new EC2 instance"
  sensitive   = true
}
