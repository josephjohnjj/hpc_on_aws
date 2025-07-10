

resource "aws_efs_file_system" "apps" {
  creation_token   = "apps-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  tags = {
    Name = "apps-efs"
  }
}

resource "aws_efs_file_system" "scratch" {
  creation_token   = "scratch-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  tags = {
    Name = "scratch-efs"
  }
}

# Mount targets for all EFS in all subnets
resource "aws_efs_mount_target" "efs_mount" {
  count = length(local.efs_filesystems) * length(local.subnet_ids)

  file_system_id  = element(values(local.efs_filesystems), count.index % length(local.efs_filesystems))
  subnet_id       = local.subnet_ids[floor(count.index / length(local.efs_filesystems))]
  security_groups = [aws_security_group.efs_sg.id]
}

# Local variable mapping efs names to IDs
locals {

  subnet_ids = [aws_subnet.public.id]

  efs_filesystems = {
    apps    = aws_efs_file_system.apps.id
    scratch = aws_efs_file_system.scratch.id
  }
}
