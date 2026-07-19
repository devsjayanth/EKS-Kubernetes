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
