# terraform/providers.tf

provider "aws" {
  region = var.aws_region
}


terraform {
  backend "remote" {
    organization = "YuanHuang"  # Replace with your Terraform Cloud organization name

    workspaces {
      name = "options_server"  # Replace with your workspace name
    }
  }

  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}