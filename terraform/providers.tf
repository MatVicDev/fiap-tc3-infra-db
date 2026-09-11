terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" {
  #   bucket         = "fiap-tc3-terraform-state"
  #   key            = "infra-db/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "fiap-tc3-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}
