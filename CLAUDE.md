# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains infrastructure-as-code configurations for deploying Amazon EKS clusters with the Flox containerd shim pre-installed. The Flox shim is a custom containerd runtime that enables Flox environments to run inside Kubernetes pods.

## Repository Structure

- `terraform/new-cluster/` - Terraform configuration for creating a complete EKS cluster with VPC and Flox shim
- `terraform/new-nodegroup/` - Terraform configuration for adding a Flox-enabled node group to an existing cluster (copy into existing Terraform config)
- `eksctl/new-cluster/` - eksctl configuration for creating a new EKS cluster with Flox shim
- `eksctl/new-nodegroup/` - eksctl configuration for adding a Flox-enabled node group to an existing cluster

## Architecture

### Flox Shim Installation Process

All configurations follow the same pattern for installing and configuring the Flox containerd shim:

1. **Pre-bootstrap**: Install Flox CLI and activate the containerd-shim-flox-installer environment
   - Installs Flox RPM from `https://flox.dev/downloads/yumrepo/flox.x86_64-linux.rpm`
   - Activates `flox/containerd-shim-flox-installer`

2. **Containerd Configuration**: Configure a custom runtime named "flox"
   - Runtime path: `/usr/local/bin/containerd-shim-flox-v2`
   - Runtime type: `io.containerd.runc.v2` (runc shim with hooks)
   - Whitelists annotations: `flox.dev/*` for both pods and containers
   - Uses systemd cgroups

3. **Node Labeling**: Nodes are labeled with `flox.dev/enabled: "true"` to enable workload scheduling via RuntimeClass

### Terraform Implementation

The Terraform code uses official AWS modules:
- `terraform-aws-modules/vpc/aws` for VPC creation
- `terraform-aws-modules/eks/aws` for EKS cluster and node groups

Key characteristics:
- Region is configurable via variable (defaults to `us-east-1`)
- Creates VPC with public, private, and intra subnets across 3 AZs
- Single NAT gateway for cost optimization
- Uses AL2023 (Amazon Linux 2023) AMI
- Node groups use cloudinit with `cloudinit_pre_nodeadm` for custom configuration
- Public endpoint access restricted to specific CIDR (see `endpoint_public_access_cidrs`)

### eksctl Implementation

Two separate configurations:
- `eksctl/new-cluster/cluster.yaml` - Creates a complete cluster from scratch
- `eksctl/new-nodegroup/nodegroup.yaml` - Adds a Flox-enabled node group to an existing cluster

Both use:
- `preBootstrapCommands` for Flox installation
- `overrideBootstrapCommand` with NodeConfig API for containerd configuration

## Common Commands

### Terraform

```bash
# Initialize Terraform
cd terraform/new-cluster
terraform init

# Plan changes
terraform plan

# Apply configuration (create infrastructure)
terraform apply

# Destroy infrastructure
terraform destroy

# Format Terraform files
terraform fmt
```

### eksctl

```bash
# Create a new cluster
eksctl create cluster -f eksctl/new-cluster/cluster.yaml

# Add node group to existing cluster
eksctl create nodegroup -f eksctl/new-nodegroup/nodegroup.yaml

# Delete cluster
eksctl delete cluster --name flox --region us-east-1

# Delete node group
eksctl delete nodegroup --cluster flox-sandbox --name flox --region us-east-1
```

## Important Configuration Details

All configurations use consistent Flox installer activation commands.

### Version Requirements

- Terraform: >= 1.6
- AWS Provider: >= 6
- Kubernetes: 1.34
- AMI: Amazon Linux 2023

### Security Considerations

When modifying configurations:
- Keep IAM policies scoped to minimum required permissions
- Update `endpoint_public_access_cidrs` to restrict cluster access appropriately
- Ensure EBS volumes remain encrypted

## Node Configuration

All node groups include:
- t3.small instances (configurable)
- 50GB gp3 encrypted EBS volumes
- The label `flox.dev/enabled: "true"` for RuntimeClass targeting
