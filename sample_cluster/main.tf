terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"

  cloud {
    organization = "NCI-Training-Team"

    workspaces {
      name = "Cluster"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
