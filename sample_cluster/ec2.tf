resource "aws_key_pair" "hcp_key" {
  key_name   = "terraform-user"
  public_key = file("${path.module}/keys/terraform-user.pub")
}



resource "aws_instance" "cluster" {
  count                       =  var.node_count # default is 3 instances
  ami                         = "ami-020cba7c55df1f615"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.hcp_key.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ssh_access.id]
  associate_public_ip_address = true

  tags = {
    Name = "gpu-ssh-server-${count.index}"
  }
}
