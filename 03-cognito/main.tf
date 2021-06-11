locals {
  common_tags = tomap({
    "maintainer" = "azebrick1@gmail.com"
})
}

provider "aws" {
  region = data.terraform_remote_state.**************.outputs.region
}

terraform {
  backend "s3" {
    dynamodb_table = "terraform-state-**************-dev"
    bucket         = "terraform-state-**************-dev"
    region         = "ap-northeast-2"
    key            = "dev/kubeflow-cognito.tfstate"
    encrypt        = true
  }
}


data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


data "terraform_remote_state" "**************" {
  backend = "s3" 
  workspace = terraform.workspace
  config = {
    dynamodb_table = "terraform-state-**************-dev"
    bucket         = "terraform-state-**************-dev"
    region         = "ap-northeast-2"
    key            = "dev/kubeflow-state.tfstate"
  }
}


provider "kubernetes" {
  host                   = data.terraform_remote_state.**************.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.**************.outputs.cluster_certificate_authority_data)
  exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.**************.outputs.cluster_id]
      command     = "aws"
    }
}

