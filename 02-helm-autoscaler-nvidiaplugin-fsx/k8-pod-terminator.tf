resource "helm_release" "kubeflow_node-terminator" {
  name       = "terminator"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-node-termination-handler"
  create_namespace = false
  namespace  = "kube-system"

  set {
    name = "enableSpotInterruptionDraining"
    value = true
  } 
  set {
    name = "enableScheduledEventDraining"
    value = true
  } 
  set {
    name = "nodeSelector.lifecycle"
    value = "Ec2Spot"
  } 
}
