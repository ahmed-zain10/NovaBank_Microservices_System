############################################
# envs/dev/providers.tf
############################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }

  backend "s3" {
    # Filled in via -backend-config, or hardcode after bootstrap_state.sh:
    # bucket         = "novabank-terraform-state-dev"
    # key            = "dev/terraform.tfstate"
    # region         = "eu-west-1"
    # dynamodb_table = "novabank-terraform-locks-dev"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Used to authenticate the kubernetes/helm providers against the EKS cluster
# created by module.eks in this same apply. Requires the cluster to already
# exist, hence the two-pass apply described in the README.
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
