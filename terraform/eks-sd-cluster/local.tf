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