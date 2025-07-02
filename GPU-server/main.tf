# -----------------------------------
# Terraform Block: Define Requirements
# -----------------------------------
terraform {
  # Specify the required providers and their sources
  required_providers {
    aws = {
      # The AWS provider comes from the official HashiCorp registry
      source  = "hashicorp/aws"
      
      # Use version 4.16 or any compatible newer patch version (e.g., 4.16.x)
      version = "~> 4.16"
    }
  }

  # Specify the minimum Terraform CLI version required
  required_version = ">= 1.2.0"

  # Configure Terraform Cloud or Enterprise usage
  cloud {
    # Name of your Terraform Cloud organization
    organization = "NCI-Training-Team"

    # Specify the workspace to use in Terraform Cloud
    workspaces {
      name = "GPU-server"
    }
  }
}

# -----------------------------------
# AWS Provider Configuration
# -----------------------------------
provider "aws" {
  # Set the AWS region to use for all AWS resources
  # us-east-1 = N. Virginia
  region = "us-east-1"
}

# -----------------------------------
# EC2 Instance Resource
# -----------------------------------

resource "aws_instance" "example" {
  # AMI to use for the instance; replace with your preferred AMI ID
  ami           = "ami-0c55b159cbfafe1f0"

  # Instance type, e.g., t3.micro, t3.medium, etc.
  instance_type = "t3.micro"

  # Assign a human-readable Name tag from the variable 'instance_name'
  tags = {
    Name = var.instance_name
  }

  # Conditionally specify Capacity Reservation for this instance
  # If 'capacity_reservation_id' variable is non-empty, the instance
  # will launch into the specified Capacity Reservation block.
  dynamic "capacity_reservation_specification" {
    for_each = var.capacity_reservation_id != "" ? [1] : []

    content {
      capacity_reservation_id = var.capacity_reservation_id
    }
  }
}
