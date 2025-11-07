# EKS with Flox Containerd Shim

Infrastructure-as-code configurations for deploying Amazon EKS clusters with the [Flox](https://flox.dev) containerd shim pre-installed. This enables running Flox development environments directly inside Kubernetes pods.

## What is the Flox Containerd Shim?

The Flox containerd shim is a custom container runtime that integrates Flox's declarative development environments with Kubernetes. It allows pods to use Flox environments, enabling reproducible and portable development and production workloads.

## Repository Structure

This repository provides three deployment options:

- **`terraform/`** - Complete EKS cluster with VPC and Flox-enabled node groups using Terraform
- **`eksctl-new-cluster/`** - Complete EKS cluster with Flox-enabled node groups using eksctl
- **`eksctl-new-nodegroup/`** - Add a Flox-enabled node group to an existing EKS cluster

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

### Option 1: Terraform

Create a complete EKS cluster with VPC:

```bash
cd terraform

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

### Option 2: eksctl - New Cluster

Create a new EKS cluster with Flox support:

```bash
# Create cluster
eksctl create cluster -f eksctl-new-cluster/cluster.yaml

# Verify nodes
kubectl get nodes --show-labels | grep flox.dev/enabled
```

### Option 3: eksctl - Add Node Group

Add a Flox-enabled node group to an existing cluster:

```bash
# Update the cluster name in eksctl-new-nodegroup/nodegroup.yaml
# to match your existing cluster

# Create the node group
eksctl create nodegroup -f eksctl-new-nodegroup/nodegroup.yaml

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

Edit `terraform/main.tf` to customize:

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
- **Volume size**: `volumeSize`

## Using Flox in Your Pods

Once your cluster is running with Flox-enabled nodes, create a RuntimeClass and use it in your pods:

```yaml
# RuntimeClass to target Flox-enabled nodes
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: flox
handler: flox
scheduling:
  nodeSelector:
    flox.dev/enabled: "true"
---
# Example pod using Flox runtime
apiVersion: v1
kind: Pod
metadata:
  name: flox-pod
  annotations:
    flox.dev/environment: "your-flox-environment"
spec:
  runtimeClassName: flox
  containers:
  - name: app
    image: your-image:latest
```

## How It Works

### Node Bootstrap Process

1. **Pre-bootstrap**: Before joining the cluster, nodes:
   - Install Flox CLI from the official RPM repository
   - Activate the `containerd-shim-flox-installer` environment
   - This installs the shim binary to `/usr/local/bin/containerd-shim-flox-v2`

2. **Containerd Configuration**: The node's containerd is configured with:
   - A new runtime handler named `flox`
   - Runtime path pointing to the Flox shim
   - Annotation whitelisting for `flox.dev/*` annotations
   - SystemdCgroup enabled for proper resource management

3. **Node Labeling**: Nodes receive the `flox.dev/enabled: "true"` label, allowing RuntimeClass to schedule Flox workloads only on these nodes

### Runtime Architecture

The Flox containerd shim is built on the runc v2 shim protocol but adds hooks to:
- Inject Flox environments into container processes
- Manage environment activation and lifecycle
- Handle Flox-specific annotations on pods and containers

## Troubleshooting

### Accessing Nodes

All nodes are configured with AWS Systems Manager access:

```bash
# List instances
aws ec2 describe-instances --filters "Name=tag:Name,Values=*flox*" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Connect via SSM
aws ssm start-session --target i-xxxxxxxxxxxxx
```

### Verifying Flox Installation

SSH or SSM into a node and verify:

```bash
# Check Flox is installed
flox --version

# Verify the shim binary exists
ls -la /usr/local/bin/containerd-shim-flox-v2

# Check containerd configuration
sudo cat /etc/containerd/config.toml | grep -A 10 flox
```

### Common Issues

**Pods not scheduling on Flox nodes**: Ensure you're using the RuntimeClass and that nodes have the `flox.dev/enabled: "true"` label.

**Shim not found**: Check that the pre-bootstrap commands completed successfully. Review cloud-init logs:
```bash
sudo cat /var/log/cloud-init-output.log
```

## Cleanup

### Terraform
```bash
cd terraform
terraform destroy
```

### eksctl
```bash
# Delete entire cluster
eksctl delete cluster --name flox --region us-east-1

# Delete only node group
eksctl delete nodegroup --cluster flox-sandbox --name flox --region us-east-1
```

## Cost Considerations

The default configurations use:
- **t3.small** instances (approximately $0.0208/hour per node)
- **Single NAT Gateway** (Terraform) - approximately $0.045/hour + data transfer
- **50GB gp3 EBS volumes** - approximately $0.08/GB/month

Adjust instance types and capacity settings based on your workload requirements.

## Security Notes

- The Terraform configuration restricts public API access to a specific CIDR (`65.21.10.97/32` in `main.tf`). **Update this before deploying.**
- All EBS volumes are encrypted by default
- Nodes have SSM access for troubleshooting but no direct SSH access
- Consider using private-only endpoints for production workloads

## License

This project is provided as-is for use with Flox environments.

## Additional Resources

- [Flox Documentation](https://flox.dev/docs)
- [Amazon EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [eksctl Documentation](https://eksctl.io/)
