locals {
  common_tags = tomap({
    "maintainer" = "azebrick1@gmail.com"
})
}



provider "aws" {
  region = "${var.region}"
}

terraform {
  backend "s3" {
    dynamodb_table = "terraform-state-**************"
    bucket         = "terraform-state-**************"
    region         = "ap-northeast-2"
    key            = "dev/kubeflow-state.tfstate"
    encrypt        = true
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}

