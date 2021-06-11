# Kubeflow on EKS with cost saving GPU SPOT and ondemand fault-over advanced autoscaling

Kubernetes, also known as K8s, is an open-source system for automating deployment, scaling, and management of containerized applications. In this guide I will be leveraging the AWS managed EKS service. Amazon Elastic Kubernetes Service (Amazon EKS) gives you the flexibility to start, run, and scale Kubernetes applications in the AWS cloud or on-premises. I will be installing Kubeflow onto a provisioned EKS cluster. Kubeflow is an end-to-end Machine Learning (ML) platform for Kubernetes. Kubernetes, AWS, and kubeflow can be quite complicated to setup; therefore, I've automated the process by writing the deployment as Infrastructure as Code (IAC) and using Terraform to deploy resources. Terraform is an open-source IAC software tool that enables you to safely and predictably create, change, and improve infrastructure.
## MINIMIZING COSTS

"Machine learning" and "Cost-savings" are two terms that rarely go together. There is no mistaking the hard truth that GPU's are expensive and hard to come buy. It's made even worse with a global chip shortage which cannot keep up. The cloud is no different and AWS P3 Nvidia Telsa V100 GPU instances can costs anywhere from $3.00/H to over $30.00/H depending on the type of EC2 instance you provision. These prices are far from trivial especially in large scale, when I was tasked with creating an environment for a data science team in the UK I knew cost had to be a big consideration. Additionally I knew I wanted the application to be highly scalable, highly available, and deployment automated.

This is what brought me to kubeflow in kubernetes. Kubernetes autoscaler allows for very fine grained control of resources and can monitor metrics such as cpu, memory, and most importantly GPU's. Due to the price of these GPU instances I knew that I wanted it to scale up from zero during events, and scale back down to 0 when not in use. This would ensure that we are only being billed for GPU instances provisioning during the duration they are utilized.

Another critical piece to this application is Amazon Spot instances which are up to 90% cheaper than traditional on-demand. AWS defines spot instances as "A Spot Instance is an instance that uses spare EC2 capacity that is available for less than the On-Demand price. The hourly price for a Spot Instance is called a Spot price. The Spot price of each instance type in each Availability Zone is set by Amazon EC2, and is adjusted gradually based on the long-term supply of and demand for Spot Instances. Your Spot Instance runs whenever capacity is available and the maximum price per hour for your request exceeds the Spot price". The word 'spare' is important here because spot instance availability is not guaranteed especially when it involves GPU instances. In fact more often than not when I attempt to provision a GPU spot instance it fails due to insufficient capacity.

By declaring spot instance worker nodes spot price to the same as the on-demand price it guarantees that you will never receive a provision error due to the pricing. However, you can still fail to provision due to there simply being insufficient spot capacity in your AZ. For high availability you cannot wait for spot capacity to open back up. This is where the kubernetes autoscaler comes in and truly shines. What it does is automatically faults to on-demand after first attempting spot instance GPU in such a way that the data-scientist using the application won't even notice the delay. When a request is made the autoscaler will prioritize cost saving spot instances over on-demand. This type of fine-grained tuning is not currently available from AWS directly and so I had to get a little creative with how to achieve this, more on that later.

## Dependencies

<li><a href="https://learn.hashicorp.com/tutorials/terraform/install-cli" target="_blank">terraform</a>		</li>	
<li><a href="https://kubernetes.io/docs/tasks/tools/" target="_blank">kubectl</a>		</li>	
<li><a href="https://www.kubeflow.org/docs/distributions/aws/deploy/install-kubeflow/" target="_blank">kfctl</a>		</li>	
<li><a href="https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html" target="_blank">eksctl</a>	</li>
<li><a href="https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html" target="_blank">aws cli</a>	</li></div>
<div class="column">
<li><a href="https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html" target="_blank">aws-iam-authenticator</a>	</li>		
<li><a href="https://stedolan.github.io/jq/download/" target="_blank">JQ</a>	</li>	
<li><a href="https://stackoverflow.com/questions/6587507/how-to-install-pip-with-python-3" target="_blank">python3-pip</a>	</li>	
<li><a href="https://pypi.org/project/yq/">YQ</a>	</li></div>	</div>

### Step one: DEPLOY THE KUBERNETES CLUSTER

The first stage of the deployment is found in the directory ‘01-eks’. This will be most significant deployment as it handles the provisioning of the EKS cluster, virtual private cloud (VPC), Node groups, GPU worker groups, and IAM roles. You will have to adjust some variables such as inputting the region of deployment in the variables.tf file, and S3 bucket for terraform-state (main.tf). Once these are set you can run terraform init and terraform apply.

Take note of all the nodegroups created here. Only one of them will actually provision instances at this stage in the deployment since the rest have their desired capacities set to 0. Depending on the use case you may be able to utilize AWS spot fleets instead of individually creating separate node groups for each instance type. That is not an option here as GPU instance types are very specific for their uses cases and prices. Also we want to separate the nodegroups as much as possible to allow for fine tuned control of auto scaling with the kubernetes internal autoscaler. More on this in the next section.
### Step two: AUTO SCALER, POD-TERMINATOR, NVIDIA DAEMONSET

Now that your cluster is up and running it is time to install things directly onto the cluster. I use the terraform resources helm and kubectl for this. kubectl_manifest is a wonderful tool for terraforming on k8s cluster as it gives you the power of the kubectl CLI in automated deployments. You can write kubernetes resources in yaml without having to reinvent the wheel. What is typically done by kubectl apply -f commands are now with a simple terraform apply.

The node-autoscaler installed here works inside the cluster to monitor resources and handle scaling of nodes. It will see if a GPU instance is requested from a kubeflow notebooks server and adjust the AWS auto scaling group desired capacity to meet the demands. I use the cluster-autoscaler-priority-expander.yaml to manually set priorities for autoscaling events within the cluster. The higher the value the higher the priority for scaling up events. The cluster-autoscaler-deployment.yaml file is where I manually set scale up/down parameters. By setting the max-node-provision-time to 7 minutes I ensure that the auto scaler will first attempt to provision spot instances and if there is no spot capacity it will fault over to on demand after the time has elapsed.

Additionally this stage installs the daemonset required for high performing nvidia gpu’s to operate on the cluster. Again a simple terraform init and terraform apply will accomplish this.
### Step three: COGNITO AND GOOGLE AUTH

This stage setups up an AWS Cognito user pool with google as an identity provider for kubeflow login/authentication with istio. Istio is a service mesh which helps with securing service-to-service communication in a Kubeflow deployment with strong identity-based authentication and authorization, providing a policy layer for supporting access controls and quotas, and automatic metrics, logs, and traces for traffic within the deployment including cluster ingress and egress.

This stage will also create a route 53 route record with a dummy temporary route which will be used in the next stage for creating the application load balancer for the istio ingress gateway.

This stage will output a shell script which when run will modify the kubeflow install configurations with the resources you’ve provisioned in the previous stages using jq and yq for yaml modification. Once again terraform init & terraform apply.

### Step four: KUBEFLOW INSTALLATION

Now it’s time to install kubeflow! This is the only stage we won’t be using terraform. Normally I automate the deployment of this in bitbucket pipelines with a docker container. The first lines of the scripts install the dependencies on the docker container, you can comment those out because here we are going to imperatively deploy. The shell scripts ends in rm – “$0” as it is self destructing to hide cognito data after kubeflow is installed, feel free to remove that if you want.

Run the shell script kubectl_update_and_install.sh in your console and kubeflow will be installed on your cluster. You can verify that your ALB was created by typing kubectl get ingress -n istio-system. The DNS name of the ALB should be listed here and in the next stage we will change that temporary record address to point to this ALB.

### Step five: UPDATE ROUTE 53

Now that kubeflow is installed and the application load balancer is provisioned it’s time to point that record you made in step 3 to the ALB. By using the terraform data source for AWS ALB we’re able to reference it inside the terraform file. You will need to update the name of the aws_route53_zone data source with the name of your hosted zone. Run a terraform init & terraform apply. Now you can navigate to the record you made and login to access your kubeflow dashboard.

You can login with a cognito user which you can create from the cognito user pool page on your AWS console or login with a supported identity provider of your choice.
### Step six: KUBENETES DASHBOARD

This step is entirely optional, but personally I enjoy the added benefits of the kubernetes dashboard. You can use Dashboard to deploy containerized applications to a Kubernetes cluster, troubleshoot your containerized application, and manage the cluster resources. You can use it to get an overview of applications running on your cluster, as well as for creating or modifying individual Kubernetes resources. Run terraform init & apply. To access the dashboard you need a login token which can be retrieved with the following steps:### I get an error message "a is not a function" or "opt_whenDone is not a function"

#########################################################
In order to access eks k8s dashboard the following commands must be made in terminal:

####### get's a list of secrets, copy to clipboard the name of last one

kubectl get secret --namespace=kubernetes-dashboard

####### Get's token, copy it to clipboard. Populat {secretName} with the name from the above step 

kubectl -n kubernetes-dashboard get secret {secretName} -o jsonpath='{.data.token}' | base64 --decode


####### Opens local host proxy 

kubectl proxy

####### Visit dashboard page in browser 
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

####### You may need to logout and back in to refresh token. If you want to view kubeflow information the namespace = kubeflow


### Step seven: FSX LUSTRE FILE-SYSTEM

This stage will setup FSX in your AWS account and provide the cluster the proper roles and controllers to utilize it. The FSX file-system I create here uses an S3 bucket as a source for data which is a great way to store data sets among your team and allow for shared access. This allows you to pull the data from S3 to run jobs inside your notebook server utilizing the high throughput of FSX Lustre. FSX will then output back to your S3 bucket in a different directory and can be scaled down when not in use.

I encountered an issue with automating this due to the recommended installation of FSX drivers utilizing kustomize which is not supported by terraform or kubectl provider. To get around this I prepossessed the yaml files by running a kustomize build and separating the yaml into individual config files so it can be deployed by terraform. They have to be separate as kubectl_manifest will not read yaml files with line breaks. Update the variables.tf file with the namespace specific to the kubeflow namespace that you created when you first logged into kubeflow. Do not confused this with the namespace where you installed the kubeflow application itself. Run terraform init & terraform apply.

This will also create a persistent volume and persistent volume claim inside your cluster. You should now see it listed as an existing volume whenever you create a notebook server. The data sets stored in your linked S3 bucket will now be available to you.

You can share access to notebooks, pipelines, and fsx access of the kubeflow namespace in which they reside by adding members of your data science team via the Manage Contributors tab in the kubeflow dashboard.


### Useful terminal commands for this repo

#########################################################
Update kubeconfig:

aws eks --region ap-northeast-2 update-kubeconfig --name kubeflow

#########################################################
Get cluster-autoscaler logs:

kubectl -n kube-system logs $(kubectl get pods -n kube-system --selector=app=cluster-autoscaler --output=jsonpath={.items..metadata.name}) > app.log

##########################################################
Find kubeflow ingress:

kubectl get ingress -n istio-system

##########################################################
Ingress logs:

kubectl -n kubeflow logs $(kubectl get pods -n kubeflow --selector=app=aws-alb-ingress-controller --output=jsonpath={.items..metadata.name}) 

#########################################################
Update kubeconfig

aws eks --region ap-northeast-2 update-kubeconfig --name kubeflow

##################################################################
Remove finalizer to hard delete PVC or PV:

kubectl -n data-science patch pvc fsx-claim -p '{"metadata":{"finalizers":null}}'

kubectl -n data-science patch pv fsx-pv -p '{"metadata":{"finalizers":null}}'