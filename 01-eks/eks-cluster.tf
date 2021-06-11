locals {
  cluster_name       = "kubeflow"
  kubernetes_version = "1.18"
}

// Limits the cluster to a single subnet for fast networking, compatability with FSX Lustre, and easier auto scaling. 
// GPU instnaces must be in the SAME subnet as the EBS volume provisioned. 
// If the EBS is for a persistent volume this can cause errors if the ASG provisions in wrong subnet
data "aws_subnet_ids" "subnet-2a-priv" {
    vpc_id      = module.vpc.vpc_id

      tags = {
    Name = "kubeflow-vpc-private-${var.region}a"
  }
    depends_on = [
    module.vpc,
  ]
}

// You need a specific AMI for the nvidia gpu's to work and be detected by kubeflow
data "aws_ami" "gpu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-gpu-node-1.16-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"] # Canonical
}

data "aws_ami" "eks_worker_ami" {
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.kubernetes_version}-*"]
  }

  most_recent = true
}

data "aws_caller_identity" "current" {}

data "aws_iam_role" "sso-admin" {
  name = "AWSReservedSSO_AdministratorAccess_************8dc"
}


module "eks" {
  tags = merge(
    local.common_tags,
    {
      Project = "kubeflow"
    }
  )
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.cluster_name
  cluster_version = local.kubernetes_version
  subnets         = module.vpc.private_subnets
  vpc_id      = module.vpc.vpc_id
  enable_irsa     = true

  ### These roles allow for bit bucket pipelines to access aws resources
    map_roles = [
          {
      rolearn = data.aws_iam_role.sso-admin.arn
      username = "system:node:{{SessionName}}"
      groups   = ["system:masters"]
    },
    {
      rolearn = "arn:aws:iam::***********:role/AWSReservedSSO_AdministratorAccess_1*************dc"
      username = "system:node:{{SessionName}}"
      groups  = ["system:masters"]
    }
  ]

  map_users = [
    {
      userarn  = "arn:aws:iam::***********:user/bitbucket-pipeline-user"
      username = "bitbucket-pipeline-user"
      groups   = ["system:masters"]
    }
  ]


//  Worker groups of spot/ondemand GPU / CPU instances
  worker_groups = [
 
    {
      name                          = "gpu-spot-small-a"
      instance_type                 = "p3.2xlarge"
      ami_id                        =   data.aws_ami.gpu.id
      spot_price                    = "4.00"
      asg_desired_capacity          = 0
      asg_min_size                  = 0
      subnets                       = [ 
      tolist(data.aws_subnet_ids.subnet-2a-priv.ids)[0]
        ]
      asg_max_size                  = 5
      root_volume_size              = 30
      additional_security_group_ids = [aws_security_group.worker_group_1.id]
      root_volume_type              = "gp2"
      kubelet_extra_args  = "--node-labels=k8s.amazonaws.com/accelerator=nvidia-tesla-v100 --node-labels=gpu-count=1 --node-labels=lifecycle=Ec2Spot --register-with-taints=spotInstance=true:PreferNoSchedule"
      tags = [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/lifecycle"
          "value"               = "Ec2Spot"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/aws.amazon.com/spot"
          "value"               = "true"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/gpu-count"
          "value"               = 1
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "value"               = "true"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/taint/spotInstance"
          "value"               = "true:PreferNoSchedule"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/kubeflow"
          "value"               = "owned"
          "propagate_at_launch" = "true"
        },
          {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/k8s.amazonaws.com/accelerator"
          "value"               = "nvidia-tesla-v100"
          "propagate_at_launch" = "true"
          }
      ]
    },

    {
      name                          = "gpu-ondemand-small-a"
      instance_type                 = "p3.2xlarge"
      ami_id                        =   data.aws_ami.gpu.id
      asg_desired_capacity          = 0
      asg_min_size                  = 0
      asg_max_size                  = 5
      root_volume_size              = 30
      additional_security_group_ids = [aws_security_group.worker_group_1.id]
      root_volume_type              = "gp2"
      subnets                       = [ 
      tolist(data.aws_subnet_ids.subnet-2a-priv.ids)[0]
        ]
      kubelet_extra_args  = "--node-labels=k8s.amazonaws.com/accelerator=nvidia-tesla-v100 --node-labels=gpu-count=1 --node-labels=lifecycle=Ec2Spot --register-with-taints=spotInstance=true:PreferNoSchedule"
      tags = [
        {
          "key"                 = " k8s.io/cluster-autoscaler/node-template/label/lifecycle"
          "value"               = "OnDemand"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/aws.amazon.com/spot"
          "value"               = "false"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/gpu-count"
          "value"               = 1
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "value"               = "true"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/taint/spotInstance"
          "value"               = "true:PreferNoSchedule"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/kubeflow"
          "value"               = "owned"
          "propagate_at_launch" = "true"
        },
          {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/k8s.amazonaws.com/accelerator"
          "value"               = "nvidia-tesla-v100"
          "propagate_at_launch" = "true"
          }
      ]
    },
    {
      name                          = "gpu-spot-large-a"
      instance_type                 = "p3.8xlarge"
      ami_id                        =   data.aws_ami.gpu.id
      spot_price                     = "10.00"
      asg_desired_capacity          = 0
      asg_min_size                  = 0
      subnets                       = [ 
      tolist(data.aws_subnet_ids.subnet-2a-priv.ids)[0]
        ]
      asg_max_size                  = 5
      root_volume_size              = 30
      additional_security_group_ids = [aws_security_group.worker_group_1.id]
      root_volume_type              = "gp2"
      kubelet_extra_args  = "--node-labels=k8s.amazonaws.com/accelerator=nvidia-tesla-v100 --node-labels=gpu-count=1 --node-labels=lifecycle=Ec2Spot --register-with-taints=spotInstance=true:PreferNoSchedule"
      tags = [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/lifecycle"
          "value"               = "Ec2Spot"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/aws.amazon.com/spot"
          "value"               = "true"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/gpu-count"
          "value"               = 4
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "value"               = "true"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/taint/spotInstance"
          "value"               = "true:PreferNoSchedule"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/kubeflow"
          "value"               = "owned"
          "propagate_at_launch" = "true"
        },
          {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/k8s.amazonaws.com/accelerator"
          "value"               = "nvidia-tesla-v100"
          "propagate_at_launch" = "true"
          }
      ]
    },
      {
      name                          = "gpu-ondemand-large-a"
      instance_type                 = "p3.8xlarge"
      ami_id                        =   data.aws_ami.gpu.id
      asg_desired_capacity          = 0
      asg_min_size                  = 0
      asg_max_size                  = 5
      root_volume_size              = 30
      subnets                       = [ 
      tolist(data.aws_subnet_ids.subnet-2a-priv.ids)[0]
        ]
      additional_security_group_ids = [aws_security_group.worker_group_1.id]
      root_volume_type              = "gp2"
      kubelet_extra_args  = "--node-labels=k8s.amazonaws.com/accelerator=nvidia-tesla-v100 --node-labels=gpu-count=1 --node-labels=lifecycle=Ec2Spot --register-with-taints=spotInstance=true:PreferNoSchedule"
      tags = [
        {
          "key"                 = " k8s.io/cluster-autoscaler/node-template/label/lifecycle"
          "value"               = "OnDemand"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/aws.amazon.com/spot"
          "value"               = "false"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/gpu-count"
          "value"               = 4
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "value"               = "true"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/taint/spotInstance"
          "value"               = "true:PreferNoSchedule"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/kubeflow"
          "value"               = "owned"
          "propagate_at_launch" = "true"
        },
          {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/k8s.amazonaws.com/accelerator"
          "value"               = "nvidia-tesla-v100"
          "propagate_at_launch" = "true"
          }
      ]
    },
    {
      name                          = "cpu-spot-a"
      instance_type                 = "m5a.2xlarge"
      asg_desired_capacity          = 0
      asg_min_size                  = 0
      subnets                       = [ 
      tolist(data.aws_subnet_ids.subnet-2a-priv.ids)[0]
        ]
      asg_max_size                  = 10
      spot_price                  = "5.00"
      root_volume_size              = 100
      additional_security_group_ids = [aws_security_group.worker_group_1.id]
      root_volume_type              = "gp2"
      kubelet_extra_args  = "--node-labels=lifecycle=Ec2Spot --register-with-taints=spotInstance=true:PreferNoSchedule"
      tags = [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/lifecycle"
          "value"               = "Ec2Spot"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/aws.amazon.com/spot"
          "value"               = "true"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/gpu-count"
          "value"               = 0
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "value"               = "true"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/taint/spotInstance"
          "value"               = "true:PreferNoSchedule"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/kubeflow"
          "value"               = "owned"
          "propagate_at_launch" = "true"
        }
      ]
    },
]


 worker_create_cluster_primary_security_group_rules = true

  worker_groups_launch_template = [
    {
      name                    = "cpu-ondemand"
      instance_type = "m5a.2xlarge"
      subnets                       = [ 
      tolist(data.aws_subnet_ids.subnet-2a-priv.ids)[0]
        ]
      asg_max_size            = 5
      kubelet_extra_args  = "--node-labels=gpu-count=0"
      asg_desired_capacity    = 2
      on_demand_percentage_above_base_capacity = 100
      asg_min_size                  = 2
      root_volume_size              = 100
      additional_security_group_ids = [aws_security_group.worker_group_1.id]
      root_volume_type              = "gp2"
      root_encrypted                = "true"

      public_ip               = true
      tags = [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/lifecycle"
          "value"               = "OnDemand"
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/aws.amazon.com/spot"
          "value"               = false
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/gpu-count"
          "value"               = 0
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "value"               = true
          "propagate_at_launch" = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/kubeflow"
          "value"               = "owned"
          "propagate_at_launch" = "true"
        }
      ]
    },
]
    
}
resource "aws_security_group" "worker_group_1" {
  name_prefix = "worker_group_1"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
