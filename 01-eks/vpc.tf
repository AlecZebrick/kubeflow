data "aws_availability_zones" "available" {}

resource "random_integer" "ip-byte2" {
  min = 0
  max = 255
}

module "vpc" {
  tags = merge(
    local.common_tags,
    {
      Project = "kubeflow"

      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    }
  )
  source = "terraform-aws-modules/vpc/aws"


  name = "kubeflow-vpc"
  cidr = "10.${random_integer.ip-byte2.result}.0.0/16"
  azs  = data.aws_availability_zones.available.names


  private_subnets      = ["10.${random_integer.ip-byte2.result}.1.0/24", "10.${random_integer.ip-byte2.result}.2.0/24", "10.${random_integer.ip-byte2.result}.3.0/24"]
  public_subnets       = ["10.${random_integer.ip-byte2.result}.4.0/24", "10.${random_integer.ip-byte2.result}.5.0/24", "10.${random_integer.ip-byte2.result}.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }


  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}
