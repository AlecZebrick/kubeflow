
variable "domain-name" {
  default = "kubeflow-**************.net"
}

data "kubernetes_ingress" "lb" {
  metadata {
    namespace = "istio-system"
    name = "istio-ingress"    
  }
}

data "aws_route53_zone" "kubeflow" {
  name         = "alpha.**************.net"
  private_zone = false
}

//There is a pattern in the naming convention, you're able to parse the name fo the ALB here
data "aws_lb" "kubeflow-elb" {
  name = join("-", [split("-", trimsuffix(data.kubernetes_ingress.lb.status.0.load_balancer.0.ingress.0.hostname, ".ap-northeast-2.elb.amazonaws.com")).0, split("-", trimsuffix(data.kubernetes_ingress.lb.status.0.load_balancer.0.ingress.0.hostname, ".ap-northeast-2.elb.amazonaws.com")).1, split("-", trimsuffix(data.kubernetes_ingress.lb.status.0.load_balancer.0.ingress.0.hostname, ".ap-northeast-2.elb.amazonaws.com")).2, split("-", trimsuffix(data.kubernetes_ingress.lb.status.0.load_balancer.0.ingress.0.hostname, ".ap-northeast-2.elb.amazonaws.com")).3])
}

resource "aws_route53_record" "kubeflow" {
  zone_id = data.aws_route53_zone.kubeflow.zone_id
  name    = var.domain-name
  type    = "A"
  allow_overwrite = true

  alias {
    name                   = data.kubernetes_ingress.lb.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = data.aws_lb.kubeflow-elb.zone_id
    evaluate_target_health = true
  }
}
