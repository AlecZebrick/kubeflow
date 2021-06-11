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


data "aws_subnet_ids" "subnet-2a-priv" {
    vpc_id      = data.terraform_remote_state.**************.outputs.VPC_ID
      tags = {
    Name = "kubeflow-vpc-private-${data.terraform_remote_state.**************.outputs.region}a"
  }
}

data "aws_s3_bucket" "data" {
  bucket = "kubeflow-fsx-lustre-data-seoul"
}
resource "aws_fsx_lustre_file_system" "kubeflow" {
  import_path      = "s3://${data.aws_s3_bucket.data.bucket}"
  export_path      = "s3://${data.aws_s3_bucket.data.bucket}/fsx-exports"
  storage_capacity = 1200
  auto_import_policy = "NEW_CHANGED"
  subnet_ids       = [
      tolist(data.aws_subnet_ids.subnet-2a-priv.ids)[0]
        ]
  security_group_ids = [data.terraform_remote_state.**************.outputs.cluster_primary_security_group_id, data.terraform_remote_state.**************.outputs.cluster_security_group_id]
    // SCRATCH_1 not available in Seoul region
  deployment_type = "SCRATCH_2"
}


resource "kubectl_manifest" "fsx-pv" {
    depends_on = [
    aws_fsx_lustre_file_system.kubeflow
  ]
yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: fsx-pv
spec:
  capacity:
    storage: 1200Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  mountOptions:
    - flock
  persistentVolumeReclaimPolicy: Recycle
  csi:
    driver: fsx.csi.aws.com
    volumeHandle: ${aws_fsx_lustre_file_system.kubeflow.id}
    volumeAttributes:
      dnsname: ${aws_fsx_lustre_file_system.kubeflow.dns_name}
      mountname: ${aws_fsx_lustre_file_system.kubeflow.mount_name}
YAML
}

//namespace here is for namesapce of notebook/pipeline server
resource "kubectl_manifest" "fsx-pvc" {
depends_on = [
    kubectl_manifest.fsx-pv
  ]
yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fsx-claim
  namespace: ${var.notebook-namespace}
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  resources:
    requests:
      storage: 1200Gi
  volumeName: fsx-pv
YAML
}

data "aws_secretsmanager_secret" "kubeflow-fsx-auth" {
  name = "kubeflow-fsx-auth"
}

data "aws_secretsmanager_secret_version" "kubeflow" {
  secret_id = data.aws_secretsmanager_secret.kubeflow-fsx-auth.id
}

resource "kubectl_manifest" "secret" {
depends_on = [
    kubectl_manifest.fsx-pv
  ]
yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: aws-secret
  namespace: kube-system
stringData:
  key_id: "${jsondecode(data.aws_secretsmanager_secret_version.kubeflow.secret_string)["KEY_ID"]}"
  access_key: "${jsondecode(data.aws_secretsmanager_secret_version.kubeflow.secret_string)["ACCESS_KEY"]}"
YAML
}


data "kubectl_filename_list" "manifests" {
    pattern = "./manifests/*.yaml"
}


resource "kubectl_manifest" "fsx-drivers" {
  depends_on = [
    kubectl_manifest.secret
  ]
      count = length(data.kubectl_filename_list.manifests.matches)
      yaml_body = file(element(data.kubectl_filename_list.manifests.matches, count.index))
}

resource "kubectl_manifest" "permissions" {
depends_on = [
    kubectl_manifest.fsx-drivers
  ]
yaml_body = <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: set-permission
  namespace: ${var.notebook-namespace}
spec:
  template:
    metadata:
      annotations:
        sidecar.istio.io/inject: "false"
    spec:
      restartPolicy: Never
      containers:
      - name: app
        image: centos
        command: ["/bin/sh"]
        args:
        - "-c"
        - "chmod 2775 /data && chown root:users /data"
        volumeMounts:
        - name: persistent-storage
          mountPath: /data
      volumes:
      - name: persistent-storage
        persistentVolumeClaim:
          claimName: fsx-claim
YAML
}