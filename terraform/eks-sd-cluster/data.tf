data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {}