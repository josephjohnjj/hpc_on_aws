# -----------------------------------
# Terraform Block: Define Requirements
# -----------------------------------
terraform {
  # Specify the required providers and their sources
  required_providers {
    aws = {
      # The AWS provider comes from the official HashiCorp registry
      source = "hashicorp/aws"

      # Use version 4.16 or any compatible newer patch version (e.g., 4.16.x)
      version = ">= 5.0"
    }
  }

  # Specify the minimum Terraform CLI version required
  required_version = ">= 1.2.0"

  # Configure Terraform Cloud or Enterprise usage
  cloud {
    # Name of your Terraform Cloud organization
    organization = "jxj900"

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
  region = var.aws_region
}


