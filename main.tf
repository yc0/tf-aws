terraform {
  required_version = ">= 0.12.0"
}

provider "aws" {
  version = ">= 2.28.1"
  region  = var.region
}

provider "random" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

data "aws_availability_zones" "available" {
}

locals {
  cluster_name = "test-eks-spot-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.6.0"

  name                 = "test-vpc-spot"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24", "10.0.4.0/24"]
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = local.cluster_name
  subnets      = module.vpc.public_subnets
  vpc_id       = module.vpc.vpc_id
#   cluster_endpoint_private_access = true  
  manage_aws_auth = true
  map_users    = var.map_users
  worker_groups_launch_template = [
    {
      name                    = "spot-1"
      override_instance_types = ["t3a.medium","t3a.small"]
      spot_instance_pools     = 2
      asg_max_size            = 5
      asg_desired_capacity    = 1
      kubelet_extra_args      = "--node-labels=kubernetes.io/lifecycle=spot"
      public_ip               = true
      autoscaling_enabled = true
    },
  ]
}