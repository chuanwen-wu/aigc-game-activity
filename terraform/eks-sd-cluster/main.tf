locals {
    # name   = basename(path.cwd) 
    name = "eks-game-gai-2"
    cluster_name = local.name
    cluster_version = 1.25
    region = "ap-northeast-1"
    partition    = data.aws_partition.current.partition

    vpc_cidr = "10.0.0.0/16"
    azs      = slice(data.aws_availability_zones.available.names, 0, 3)

    tags = {
        Blueprint  = local.name
        GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
    }
}

################################################################################
# Cluster
################################################################################

#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.13"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_cluster_security_group = false
  create_node_security_group    = false

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    # We need to add in the Karpenter node IAM role for nodes launched by Karpenter
    {
      rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
  ]

  eks_managed_node_groups = {
      # blue = {}
      green = {
        min_size     = 2
        max_size     = 2
        desired_size = 2

        instance_types = ["t3.large"]
        # capacity_type  = "SPOT"
        iam_role_additional_policies = {
          # Required by Karpenter
          ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        }
      }
  }

  tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.name
  })
}