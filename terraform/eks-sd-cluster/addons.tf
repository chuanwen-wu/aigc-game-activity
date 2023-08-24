################################################################################
# EKS Blueprints Addons
################################################################################
module "efs_csi_driver_irsa" {
    source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    version               = "~> 5.14"
    role_name             = format("%s-%s", local.cluster_name, "efs-csi-driver")
    attach_efs_csi_policy = true
    oidc_providers = {
      main = {
        provider_arn               = module.eks.oidc_provider_arn
        namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
      }
    }
    tags = local.tags
}
#---------------------------------------------------------------
# IRSA for EBS CSI Driver
#---------------------------------------------------------------
module "ebs_csi_driver_irsa" {
    source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    version               = "~> 5.14"
    role_name             = format("%s-%s", local.cluster_name, "ebs-csi-driver")
    attach_ebs_csi_policy = true
    oidc_providers = {
      main = {
        provider_arn               = module.eks.oidc_provider_arn
        namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
      }
    }
    tags = local.tags
}

#---------------------------------------------------------------
# IRSA for VPC CNI
#---------------------------------------------------------------
module "vpc_cni_irsa" {
    source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    version               = "~> 5.14"
    role_name             = format("%s-%s", local.cluster_name, "vpc-cni")
    attach_vpc_cni_policy = true
    vpc_cni_enable_ipv4   = true
    oidc_providers = {
      main = {
        provider_arn               = module.eks.oidc_provider_arn
        namespace_service_accounts = ["kube-system:aws-node"]
      }
    }
    tags = local.tags
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # We want to wait for the Fargate profiles to be deployed first
  create_delay_dependencies = [for prof in module.eks.fargate_profiles : prof.fargate_profile_arn]
      eks_addons = {
        aws-ebs-csi-driver = {
            service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
        }
        aws-efs-csi-driver = {
            service_account_role_arn = module.efs_csi_driver_irsa.iam_role_arn
        }
        coredns = {
            preserve = true
        }
        vpc-cni = {
            service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
            preserve                 = true
        }
        kube-proxy = {
            preserve = true
        }
    }
    
  enable_aws_load_balancer_controller    = true
  enable_karpenter = true
  karpenter = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
  }

  tags = local.tags
}

################################################################################
# Karpenter
################################################################################

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["c", "m"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["2", "4", "8", "16", "32"]
        - key: "karpenter.k8s.aws/instance-hypervisor"
          operator: In
          values: ["nitro"]
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: ${jsonencode(local.azs)}
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
        - key: "karpenter.sh/capacity-type" # If not included, the webhook for the AWS cloud provider will default to on-demand
          operator: In
          values: ["spot", "on-demand"]
      kubeletConfiguration:
        containerRuntime: containerd
        maxPods: 110
      limits:
        resources:
          cpu: 1000
      consolidation:
        enabled: true
      providerRef:
        name: default
      ttlSecondsUntilExpired: 604800 # 7 Days = 7 * 24 * 60 * 60 Seconds
  YAML

  depends_on = [
    module.eks_blueprints_addons
  ]
}

resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      instanceProfile: ${module.eks_blueprints_addons.karpenter.node_instance_profile_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML
}

#---------------------------------------------------------------
# Allow karpenter controller to run bottlerocket snapshot instance.
# Additional IAM policies for a IAM role for service accounts
#---------------------------------------------------------------
data "aws_iam_policy_document" "karpenter-snapshot-policy" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:RunInstances"]
    resources = ["arn:aws:ec2:${local.region}::snapshot/*"]
  }
}

resource "aws_iam_policy" "karpenter-snapshot-policy" {
  name        = "karpenter-snapshot-policy-${local.region}"
  description = "Allow karpenter controller to run bottlerocket snapshot instance."
  policy      = data.aws_iam_policy_document.karpenter-snapshot-policy.json
}

#need to change the default IRSA role name. - give up the automation, use manaully to bind the policy.
resource "aws_iam_role_policy_attachment" "karpenter-bottlerocket-attach" {
  role       = module.eks_blueprints_addons.karpenter.iam_role_name
  policy_arn = aws_iam_policy.karpenter-snapshot-policy.arn
}