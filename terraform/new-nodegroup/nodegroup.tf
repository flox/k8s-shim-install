module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "21.6.1"

  name         = "separate-eks-mng"
  cluster_name = local.name

  subnet_ids = module.vpc.private_subnets

  instance_types = ["t3.small"]

  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]
  cluster_service_cidr              = module.eks.cluster_service_cidr

  ami_type     = "AL2023_x86_64_STANDARD"
  desired_size = 1
  min_size     = 0
  max_size     = 10

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
