# EKS Cluster Setup:

Instructions and configurations to deploy an Amazon EKS cluster in the `ap-south-1` region.

## Prerequisites
- AWS CLI configured
- eksctl installed
- kubectl installed

## Method 1: Using Shell Commands

Run the following commands sequentially to create and configure the cluster.

```bash

# ==========================================
#  Create EKS Cluster
# ==========================================
eksctl create cluster --name=dev-cluster-01 \
                      --region=ap-south-1 \
                      --zones=ap-south-1a,ap-south-1b \
                      --without-nodegroup
                  
eksctl utils associate-iam-oidc-provider \
    --region ap-south-1 \
    --cluster dev-cluster-01 \
    --approve
   
eksctl create nodegroup --cluster=dev-cluster-01 \
                        --region=ap-south-1 \
                        --name=dev-cluster-01-ng-private \
                        --node-type=t3.medium \
                        --nodes-min=2 \
                        --nodes-max=3 \
                        --node-volume-size=20 \
                        --managed \
                        --asg-access \
                        --external-dns-access \
                        --full-ecr-access \
                        --appmesh-access \
                        --alb-ingress-access \
                        --node-private-networking
# ==========================================
# Update kubeconfig file
# ==========================================
aws eks update-kubeconfig --name dev-cluster-01 --region ap-south-1

# ==========================================
# Update EKS Cluster Components
# ==========================================

# 1. Update Control Plane (Specify target version, e.g., 1.36)
eksctl upgrade cluster --name=dev-cluster-01 \
                       --version=1.36 \
                       --approve
# ==========================================
# 2. Update Node Group (Upgrades nodes to match control plane version)
# ==========================================
eksctl upgrade nodegroup --cluster=dev-cluster-01 \
                         --name=dev-cluster-01-ng-private
# ==========================================
# 3. Update Compute (Scale node group capacity)
# ==========================================
eksctl scale nodegroup --cluster=dev-cluster-01 \
                       --name=dev-cluster-01-ng-private \
                       --nodes=3 \
                       --nodes-min=2 \
                       --nodes-max=5
# ==========================================
# 4. Update EKS Add-ons (e.g., vpc-cni, coredns, kube-proxy)
# ==========================================
eksctl update addon --cluster=dev-cluster-01 --name=vpc-cni
eksctl update addon --cluster=dev-cluster-01 --name=coredns
eksctl update addon --cluster=dev-cluster-01 --name=kube-proxy

# ==========================================
# Delete the EKS Cluster
# ==========================================
eksctl delete cluster --name dev-cluster-01 --region ap-south-1

```

## Method 2: Using eksctl YAML Configuration

Use the declarative `dev-cluster01.yml.yml` file provided in this repository.

```bash
# Create cluster using the YAML file
eksctl create cluster -f dev-cluster01.yml
```

## Cluster Operations

### Update Control Plane and Node Groups

***

# dev-cluster01.yml.yml

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: dev-cluster-01
  region: ap-south-1
  version: "1.36"

availabilityZones:
  - ap-south-1a
  - ap-south-1b

iam:
  withOIDC: true

managedNodeGroups:
  - name: dev-cluster-01-ng-private
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 2
    maxSize: 5
    volumeSize: 20
    privateNetworking: true
    iam:
      withAddonPolicies:
        autoScaler: true
        externalDNS: true
        imageBuilder: true
        appMesh: true
        albIngress: true
        cloudWatch: true

addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest

cloudWatch:
  clusterLogging:
    enableTypes:
      - api
      - audit
      - authenticator
      - controllerManager
      - scheduler
```
