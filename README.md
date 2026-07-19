# EKS Cluster Setup

Instructions to deploy an Amazon EKS cluster in the `ap-south-1` region.

## Prerequisites
- AWS CLI configured
- eksctl installed
- kubectl installed

---

## Method 1: Using Shell Commands

Run the following commands sequentially to create and configure the cluster.

```bash
# 1. Create Cluster Control Plane
eksctl create cluster --name=mycluster \
                      --region=ap-south-1 \
                      --zones=ap-south-1a,ap-south-1b \
                      --version=1.36 \
                      --without-nodegroup

# 2. Associate IAM OIDC Provider
eksctl utils associate-iam-oidc-provider \
    --region=ap-south-1 \
    --cluster=mycluster \
    --approve

# 3. Create Managed Node Group
eksctl create nodegroup --cluster=mycluster \
                        --region=ap-south-1 \
                        --name=mycluster-ng-private \
                        --node-type=t3.medium \
                        --nodes-min=2 \
                        --nodes-max=3 \
                        --node-volume-size=20 \
                        --managed \
                        --node-private-networking \
                        --asg-access \
                        --external-dns-access \
                        --full-ecr-access \
                        --appmesh-access \
                        --alb-ingress-access

# 4. Update kubeconfig
aws eks update-kubeconfig --name=mycluster --region=ap-south-1
```

---

## Method 2: Using eksctl YAML Configuration

Use the declarative `mycluster-eks.yml` file. This is the recommended approach for version control.

```bash
# 1. Create the cluster using the YAML configuration file
eksctl create cluster -f mycluster-eks.yml

# 2. Update your local kubeconfig
aws eks update-kubeconfig --name=mycluster --region=ap-south-1
```

---

## Update Control Plane

Upgrade the EKS control plane to a specific Kubernetes version.

```bash
eksctl upgrade cluster --name=mycluster \
                       --region=ap-south-1 \
                       --version=1.36 \
                       --approve
```

## Upgrade Node Group

Upgrade the managed node group to match the control plane version.

```bash
eksctl upgrade nodegroup --cluster=mycluster \
                         --region=ap-south-1 \
                         --name=mycluster-ng-private
```

## Scale Compute

Adjust the desired, minimum, and maximum capacity of the node group.

```bash
eksctl scale nodegroup --cluster=mycluster \
                       --region=ap-south-1 \
                       --name=mycluster-ng-private \
                       --nodes=3 \
                       --nodes-min=2 \
                       --nodes-max=5
```

## Update Add-ons

Update the core EKS add-ons to their latest compatible versions.

```bash
eksctl update addon --cluster=mycluster --region=ap-south-1 --name=vpc-cni --version=latest
eksctl update addon --cluster=mycluster --region=ap-south-1 --name=coredns --version=latest
eksctl update addon --cluster=mycluster --region=ap-south-1 --name=kube-proxy --version=latest
```

## Verify Cluster

Check the status of the nodes and cluster components.

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

## Cleanup

Delete the cluster and all associated resources.

```bash
# If created via Shell
eksctl delete cluster --name=mycluster --region=ap-south-1

# If created via YAML
eksctl delete cluster -f mycluster-eks.yml
```

---
Here is the equivalent simple Terraform configuration using the official AWS EKS and VPC modules. 

Note: Kubernetes version `1.36` is not yet released by AWS (current latest is `1.31`). I have included it as requested, but added a comment to change it to a valid version when you actually run it.

### main.tf

```hcl
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
```
---

### Terraform configuration

1. Initialize Terraform and download the required modules:
```bash
terraform init
```

2. Review the resources that will be created:
```bash
terraform plan
```

3. Apply the configuration to create the cluster:
```bash
terraform apply -auto-approve
```

4. Update your local kubeconfig to access the new cluster:
```bash
aws eks update-kubeconfig --name mycluster --region ap-south-1
```

5. Verify the cluster:
```bash
kubectl get nodes
```

### Cleanup
To destroy the cluster and all associated resources:
```bash
terraform destroy -auto-approve
```
