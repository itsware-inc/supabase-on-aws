provider "aws" {
  region  = var.primary_region
  profile = var.aws_primary_profile
}

provider "aws" {
  alias = "secondary"
  region = var.secondary_region
  profile = var.aws_secondary_profile
}

data "aws_availability_zones" "primary" {}
data "aws_availability_zones" "secondary" {
  provider = aws.secondary
}

locals {

  primary_vpc_cidr   = "10.0.0.0/16"
  primary_azs        = slice(data.aws_availability_zones.primary.names, 0, 3)

  secondary_vpc_cidr   = "10.1.0.0/16"
  secondary_azs        = slice(data.aws_availability_zones.secondary.names, 0, 2)
}

module "primary_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "supabase-primary-vpc"
  cidr = local.primary_vpc_cidr

  azs              = local.primary_azs
  public_subnets   = [for k, v in local.primary_azs : cidrsubnet(local.primary_vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.primary_azs : cidrsubnet(local.primary_vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.primary_azs : cidrsubnet(local.primary_vpc_cidr, 8, k + 6)]

}

module "secondary_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = { aws = aws.secondary }

  name = "supabase-secondary-vpc"
  cidr = local.secondary_vpc_cidr

  azs              = local.secondary_azs
  public_subnets   = [for k, v in local.secondary_azs : cidrsubnet(local.secondary_vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.secondary_azs : cidrsubnet(local.secondary_vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.secondary_azs : cidrsubnet(local.secondary_vpc_cidr, 8, k + 6)]

}

