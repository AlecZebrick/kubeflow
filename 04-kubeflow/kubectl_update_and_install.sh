
### Install dependencies for yaml yq, can comment out for local use
apt-get update
apt install python3-pip -y
apt-get install jq -y
pip3 install yq


### Setup pre-install
aws eks --region ap-northeast-2 update-kubeconfig --name kubeflow
aws configure set default.region ap-northeast-2
export CONFIG_URI="https://raw.githubusercontent.com/kubeflow/manifests/v1.2-branch/kfdef/kfctl_aws_cognito.v1.2.0.yaml"
export AWS_CLUSTER_NAME=kubeflow

### Env variables
export certArn=arn:aws:acm:ap-northeast-2:***********:certificate/8cd2d192-9011-**************
export cognitoAppClientId=42tl12304gr91h2t6fu9cvn6qh
export cognitoUserPoolArn=arn:aws:cognito-idp:ap-northeast-2:***********:userpool/ap-northeast-2_RB2KAdwjJ
export cognitoUserPoolDomain=kubeflow-**************
export region=ap-northeast-2

### Edit kubeflow config for cognito
yq --arg certArn "$certArn" -y '(.spec.plugins[].spec.auth.cognito.certArn)|=$certArn' kfctl_aws.yaml -i
yq --arg cognitoAppClientId "$cognitoAppClientId" -y '(.spec.plugins[].spec.auth.cognito.cognitoAppClientId)|=$cognitoAppClientId' kfctl_aws.yaml -i
yq --arg cognitoUserPoolArn "$cognitoUserPoolArn" -y '(.spec.plugins[].spec.auth.cognito.cognitoUserPoolArn)|=$cognitoUserPoolArn' kfctl_aws.yaml -i
yq --arg cognitoUserPoolDomain "$cognitoUserPoolDomain" -y '(.spec.plugins[].spec.auth.cognito.cognitoUserPoolDomain)|=$cognitoUserPoolDomain' kfctl_aws.yaml -i
yq --arg region "$region" -y '(.spec.plugins[].spec.region)|=$region' kfctl_aws.yaml -i

#Install kubeflow
kfctl apply -V -f kfctl_aws.yaml

rm -- "$0"

