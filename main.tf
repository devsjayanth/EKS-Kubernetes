terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# ==========================================
# 1. VPC and Subnets
# ==========================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"

  name = "mycluster-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-south-1a", "ap-south-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# ==========================================
# 2. EKS Cluster and Node Group
# ==========================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.0"

  cluster_name    = "mycluster"
  # Note: Change to a valid version (e.g., "1.30" or "1.31") as 1.36 is not yet available
  cluster_version = "1.36" 

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # IAM OIDC Provider for IRSA
  enable_irsa = true

  # Managed Node Group
  eks_managed_node_groups = {
    mycluster-ng-private = {
      name           = "mycluster-ng-private"
      instance_types = ["t3.medium"]

      min_size     = 2
      max_size     = 5
      desired_size = 2

      subnet_ids   = module.vpc.private_subnets
      disk_size    = 20

      # Attach required IAM policies
      attach_cluster_autoscaler_policy = true
      attach_external_dns_policy       = true
      attach_ecr_policy                = true
      attach_lb_controller_policy      = true # Replaces alb-ingress
      attach_appmesh_policy            = true
      attach_cloudwatch_policy         = true

      labels = {
        role = "workers"
      }

      tags = {
        Environment = "dev"
        Project     = "observability"
      }
    }
  }

  tags = {
    Environment = "dev"
    Project     = "observability"
  }
}

# ==========================================
# 3. Outputs
# ==========================================
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS Cluster Name"
  value       = module.eks.cluster_name
}
