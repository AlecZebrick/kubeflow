// These outputs are critical for later stages of this deployment

output "cluster_endpoint" {
    description = "The endpoint of cluster"
    value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
    description = "Cluser cert auth data"
    value = module.eks.cluster_certificate_authority_data
}

output "cluster_id" {
    description = "Cluster name"
    value = module.eks.cluster_id
}

output "arn_id" {
    description = "ARN admin role"
    value = data.aws_iam_role.sso-admin.arn
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "workers_asg_names" {
    value = module.eks.workers_asg_names
}

output "region" {
    description = "Region variable"
    value = var.region
}

output "AMI" {
    description = "GPU_AMI"
    value = data.aws_ami.gpu
}

output "VPC_ID" {
    description = "vpc_id"
    value = module.vpc.vpc_id
}

output "cluster_primary_security_group_id" {
    description = "Cluster primary security group"
    value = module.eks.cluster_primary_security_group_id
}

output "cluster_security_group_id" {
    description = "Cluster additional security group"
    value = module.eks.cluster_security_group_id
}