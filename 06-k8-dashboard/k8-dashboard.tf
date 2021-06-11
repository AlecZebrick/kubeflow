module "kubernetes_dashboard" {
  source = "cookielab/dashboard/kubernetes"
  version = "0.11.0"
  kubernetes_namespace_create = true
  kubernetes_dashboard_csrf = "my-csrf"
}

resource "kubernetes_cluster_role" "kubernetes_dashboard_viewer_cluster_role" {
  metadata {
    name      = "kubernetes-dashboard-viewer"

    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }

  rule {
    api_groups = [""]
    resources  = [
      "configmaps",
      "componentstatuses",
      "endpoints",
      "persistentvolumeclaims",
      "pods",
      "replicationcontrollers",
      "replicationcontrollers/scale",
      "replicationcontrollers/status",
      "serviceaccounts",
      "services",
      "nodes",
      "persistentvolumeclaims",
      "persistentvolumes",
      "bindings",
      "events",
      "limitranges",
      "namespaces/status",
      "pods/log",
      "pods/status",
      "resourcequotas",
      "resourcequotas/status",
      "nodes",
      "namespaces",
      "podtemplates"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = [
      "daemonsets",
      "deployments",
      "deployments/scale",
      "replicasets",
      "replicasets/scale",
      "statefulsets",
      "controllerrevisions"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["autoscaling"]
    resources  = [
      "horizontalpodautoscalers"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = [
      "cronjobs",
      "jobs"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = [
      "ingresses"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["policy"]
    resources  = [
      "poddisruptionbudgets",
      "podsecuritypolicies"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = [
      "networkpolicies",
      "ingressclasses",
      "ingresses"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = [
      "storageclasses",
      "volumeattachments",
      "csidrivers",
      "csinodes"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = [
      "clusterrolebindings",
      "clusterroles",
      "roles",
      "rolebindings"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["admissionregistration.k8s.io"]
    resources  = [
      "mutatingwebhookconfigurations",
      "validatingwebhookconfigurations"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = [
      "customresourcedefinitions"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apiregistration.k8s.io"]
    resources  = [
      "apiservices"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["authentication.k8s.io"]
    resources  = [
      "apisertokenreviewsvices"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["authorization.k8s.io"]
    resources  = [
      "localsubjectaccessreviews",
      "selfsubjectaccessreviews",
      "selfsubjectrulesreviews",
      "subjectaccessreviews"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = [
      "certificatesigningrequests"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = [
      "leases"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["discovery.k8s.io"]
    resources  = [
      "endpointslices"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["events.k8s.io"]
    resources  = [
      "events"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["node.k8s.io"]
    resources  = [
      "runtimeclasses"
    ]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["scheduling.k8s.io"]
    resources  = [
      "priorityclasses"
    ]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "kubernetes_dashboard" {
  metadata {
    name = "kubernetes-dashboard-viewer"
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "kubernetes-dashboard-viewer"
  }

  subject {
    kind = "ServiceAccount"
    name = "kubernetes-dashboard"
    namespace = "kubernetes-dashboard"
  }
}