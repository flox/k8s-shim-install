# EKS with Flox Containerd Shim

Infrastructure-as-code configurations for deploying Amazon EKS clusters with the [Flox](https://flox.dev) containerd shim pre-installed. This enables running Flox development environments directly inside Kubernetes pods.

See the [Flox documentation](https://flox.dev/docs/k8s/intro) for more details.

## Repository Structure

This repository provides four deployment options:

- **`terraform/new-cluster/`** - Complete EKS cluster with VPC and Flox-enabled node groups using Terraform
- **`terraform/new-nodegroup/`** - Add a Flox-enabled node group to an existing EKS cluster using Terraform
- **`eksctl/new-cluster/`** - Complete EKS cluster with Flox-enabled node groups using eksctl
- **`eksctl/new-nodegroup/`** - Add a Flox-enabled node group to an existing EKS cluster using eksctl

## Prerequisites

### For Terraform
- [Terraform](https://www.terraform.io/downloads) >= 1.6
- AWS CLI configured with appropriate credentials
- AWS account with permissions to create VPC, EKS, and EC2 resources

### For eksctl
- [eksctl](https://eksctl.io/installation/) >= 0.150.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- AWS CLI configured with appropriate credentials

## Quick Start

### Option 1: Terraform - New Cluster

Create a complete EKS cluster with VPC:

```bash
cd terraform/new-cluster

# Initialize Terraform
terraform init

# Review the planned changes
terraform plan

# Create the infrastructure
terraform apply

# Configure kubectl
aws eks update-kubeconfig --name flox-eks-tf --region us-east-1
```

**Note**: The default region in `main.tf` is `us-east-1`. Update `local.region` if needed.

### Option 2: Terraform - Add Node Group

Add a Flox-enabled node group to an existing Terraform-managed EKS cluster:

```bash
# Copy nodegroup.tf into your existing Terraform configuration directory
cp terraform/new-nodegroup/nodegroup.tf /path/to/your/cluster/terraform/

# Update nodegroup.tf to match your existing resource names
# (module names, local variables, etc.)

cd /path/to/your/cluster/terraform/

# Review the planned changes
terraform plan

# Create the node group
terraform apply

# Verify nodes
kubectl get nodes --show-labels | grep flox.dev/enabled
```

**Note**: The `nodegroup.tf` file references `module.eks`, `module.vpc`, and `local.name` - adjust these to match your existing Terraform configuration's resource names.

### Option 3: eksctl - New Cluster

Create a new EKS cluster with Flox support:

```bash
# Create cluster
eksctl create cluster -f eksctl/new-cluster/cluster.yaml

# Verify nodes
kubectl get nodes --show-labels | grep flox.dev/enabled
```

### Option 4: eksctl - Add Node Group

Add a Flox-enabled node group to an existing cluster:

```bash
# Update the cluster name in eksctl/new-nodegroup/nodegroup.yaml
# to match your existing cluster

# Create the node group
eksctl create nodegroup -f eksctl/new-nodegroup/nodegroup.yaml

# Verify nodes
kubectl get nodes --show-labels | grep flox.dev/enabled
```

## Configuration

### Key Configuration Elements

All configurations install and configure the Flox shim with:

1. **Flox Installation**: Installs Flox CLI via RPM during node bootstrap
2. **Shim Activation**: Activates the `containerd-shim-flox-installer` environment
3. **Containerd Runtime**: Configures a custom `flox` runtime in containerd
4. **Node Labels**: Adds `flox.dev/enabled: "true"` label for pod scheduling

### Customization

#### Terraform

Edit `terraform/new-cluster/main.tf` to customize:

- **Region**: Change `local.region` (default: `us-east-1`)
- **Cluster name**: Change `local.name` (default: `flox-eks-tf`)
- **Instance type**: Change `instance_types` (default: `t3.small`)
- **Node capacity**: Adjust `desired_size`, `min_size`, `max_size`
- **Access CIDR**: Update `endpoint_public_access_cidrs` for security

#### eksctl

Edit the YAML files to customize:

- **Cluster name**: `metadata.name`
- **Region**: `metadata.region`
- **Instance type**: `managedNodeGroups[].instanceType`
- **Capacity**: `desiredCapacity`, `minSize`, `maxSize`

### Common Issues

**Pods not scheduling on Flox nodes**: Ensure you're using the RuntimeClass and that nodes have the `flox.dev/enabled: "true"` label.

**Shim not found**: Check that the pre-bootstrap commands completed successfully. Review cloud-init logs from **Actions->Monitor and troubleshoot->Get system log** in the EC2 console.

## Cleanup

### Terraform
```bash
cd terraform/new-cluster
terraform destroy
```

### eksctl
```bash
# Delete entire cluster
eksctl delete cluster --name flox --region us-east-1

# Delete only node group
eksctl delete nodegroup --cluster flox-sandbox --name flox --region us-east-1
```

## Additional Resources

- [Flox Documentation](https://flox.dev/docs)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [eksctl Documentation](https://eksctl.io/)
