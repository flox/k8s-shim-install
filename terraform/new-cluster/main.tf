data "aws_availability_zones" "available" {}

locals {
  name   = "garbas-flox-eks-tf"
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway = true
  single_nat_gateway = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = "1.34"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access       = true

  enable_cluster_creator_admin_permissions = true

  # EKS Addons
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    ng-flox-containerd-config = {
      name           = "flox-shim"
      instance_types = ["t3.small"]

      ami_type     = "AL2023_x86_64_STANDARD"
      desired_size = 1
      min_size     = 0
      max_size     = 10

      subnet_ids = module.vpc.private_subnets

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      labels = {
        "flox.dev/enabled" = "true"
      }

      cloudinit_pre_nodeadm = [
        {
          content_type = "text/x-shellscript; charset=\"us-ascii\""
          content      = <<-EOT
            #!/bin/bash
            dnf install -y https://flox.dev/downloads/yumrepo/flox.x86_64-linux.rpm
            flox activate -r flox/containerd-shim-flox-installer --trust
          EOT
        },
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              cluster: {}
              containerd:
                config: |
                  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.flox]
                    # Our shim is a build of the runc shim with hooks, so override runtime_path
                    # here but otherwise obey all the runc protocol specifications.
                    runtime_path = "/usr/local/bin/containerd-shim-flox-v2"
                    runtime_type = "io.containerd.runc.v2"
                    # Whitelist all annotations starting with "flox.dev/"
                    pod_annotations = [ "flox.dev/*" ]
                    container_annotations = [ "flox.dev/*" ]
                  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.flox.options]
                    SystemdCgroup = true
              instance:
                localStore: {}
              kubelet: {}
          EOT
        }
      ]
    }
  }
}

############################
# Outputs
############################
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

