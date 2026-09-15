terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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

# Postgres roda dentro do cluster EKS provisionado por fiap-tc3-infra-k8s (ver
# main.tf) — autentica com o mesmo padrão de token de curta duração usado lá.
data "aws_eks_cluster" "oficina" {
  name = data.aws_ssm_parameter.eks_cluster_name.value
}

data "aws_eks_cluster_auth" "oficina" {
  name = data.aws_ssm_parameter.eks_cluster_name.value
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.oficina.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.oficina.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.oficina.token
}
