//This will output a shell script which when run will modify the kubeflow install configurations
// with the resources you’ve provisioned in the previous stages using jq and yq for yaml modification.

locals {
  script = <<SHELL_SCRIPT

### Install dependencies for yaml yq, can comment out for local use
apt-get update
apt install python3-pip -y
apt-get install jq -y
pip3 install yq


### Setup pre-install
aws eks --region ${data.terraform_remote_state.**************.outputs.region} update-kubeconfig --name kubeflow
aws configure set default.region ${data.terraform_remote_state.**************.outputs.region}
export CONFIG_URI="https://raw.githubusercontent.com/kubeflow/manifests/v1.2-branch/kfdef/kfctl_aws_cognito.v1.2.0.yaml"
export AWS_CLUSTER_NAME=kubeflow

### Env variables
export certArn=${data.aws_acm_certificate.**************.arn}
export cognitoAppClientId=${aws_cognito_user_pool_client.client.id}
export cognitoUserPoolArn=${aws_cognito_user_pool.kubeflow.arn}
export cognitoUserPoolDomain=kubeflow-**************
export region=${data.terraform_remote_state.**************.outputs.region}

### Edit kubeflow config for cognito
yq --arg certArn "$certArn" -y '(.spec.plugins[].spec.auth.cognito.certArn)|=$certArn' kfctl_aws.yaml -i
yq --arg cognitoAppClientId "$cognitoAppClientId" -y '(.spec.plugins[].spec.auth.cognito.cognitoAppClientId)|=$cognitoAppClientId' kfctl_aws.yaml -i
yq --arg cognitoUserPoolArn "$cognitoUserPoolArn" -y '(.spec.plugins[].spec.auth.cognito.cognitoUserPoolArn)|=$cognitoUserPoolArn' kfctl_aws.yaml -i
yq --arg cognitoUserPoolDomain "$cognitoUserPoolDomain" -y '(.spec.plugins[].spec.auth.cognito.cognitoUserPoolDomain)|=$cognitoUserPoolDomain' kfctl_aws.yaml -i
yq --arg region "$region" -y '(.spec.plugins[].spec.region)|=$region' kfctl_aws.yaml -i

#Install kubeflow
kfctl apply -V -f kfctl_aws.yaml

rm -- "$0"
SHELL_SCRIPT
}
  
resource "local_file" "kubectl_config_update" {
    content     = <<-EOL
    ${local.script}
    EOL
    filename = "../04-kubeflow/kubectl_update_and_install.sh"
}