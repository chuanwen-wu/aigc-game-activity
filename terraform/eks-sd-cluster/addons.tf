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
  name        = "karpenter-snapshot-policy-${local.cluster_name}-${local.region}"
  description = "Allow karpenter controller to run bottlerocket snapshot instance."
  policy      = data.aws_iam_policy_document.karpenter-snapshot-policy.json
}

#need to change the default IRSA role name. - give up the automation, use manaully to bind the policy.
resource "aws_iam_role_policy_attachment" "karpenter-bottlerocket-attach" {
  role       = module.eks_blueprints_addons.karpenter.iam_role_name
  policy_arn = aws_iam_policy.karpenter-snapshot-policy.arn
}


#---------------------------------------------------------------
# EFS module
# create it in the eks VPC, and open internal access for security group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system
#---------------------------------------------------------------
resource "aws_efs_file_system" "efs" {
   creation_token = "${local.name}-efs"
   encrypted = "true"
 tags = {
     Name = "EFS"
     Terraform   = "true"
     auto-delete = "no"
   }
 }

resource "aws_efs_mount_target" "efs-mt" {
   count = length(module.vpc.private_subnets)
   file_system_id  = aws_efs_file_system.efs.id
   subnet_id = module.vpc.private_subnets[count.index]
   security_groups = [aws_security_group.efs.id]
 }
 
resource "aws_security_group" "efs" {
   name = "efs-sg"
   description= "Allos inbound efs traffic from internal vpc"
   vpc_id = module.vpc.vpc_id

    ingress {
      description      = "NFS from VPC"
      from_port        = 2049
      to_port          = 2049
      protocol         = "tcp"
      cidr_blocks      = [local.vpc_cidr]
    }
  
    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
    }
 }