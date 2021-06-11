

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.**************.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.**************.outputs.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.**************.outputs.cluster_id]
      command     = "aws"
    }
  }
}