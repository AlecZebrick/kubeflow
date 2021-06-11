provider "kubectl" {
  host                   = data.terraform_remote_state.**************.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.**************.outputs.cluster_certificate_authority_data)
  load_config_file       = false
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.**************.outputs.cluster_id]
      command     = "aws"
    }
}


// They have to be separate as kubectl_manifest will not read yaml files with line breaks

data "kubectl_filename_list" "manifests" {
    pattern = "./manifests/*.yaml"
}


resource "kubectl_manifest" "autoscaler_nvidia_plugin" {
      count = length(data.kubectl_filename_list.manifests.matches)
      yaml_body = file(element(data.kubectl_filename_list.manifests.matches, count.index))
}