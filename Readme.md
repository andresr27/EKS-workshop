# Set up Access to the cluster for Tiller

> kubectl apply -f rbac.yaml
> helm init --service-account tiller 

Note: Tiller needs to be secure:

> run `helm init` with the --tiller-tls-verify flag.

https://docs.helm.sh/using_helm/#securing-your-helm-installation

See edit in Method 2 to ingnore insecure installation for the metrics-server deployed.


> helm completion bash >> ~/.bash_completion
> . /etc/profile.d/bash_completion.sh
> . ~/.bash_completion


# Using HELM to deploy images

> helm search nginx

> helm install --name mywebserver bitnami/nginx

> kubectl describe deployment mywebserver

Clean up

> helm list

> helm delete --purge mywebserver




# Deploy Micreservices with Helm


> helm create Demokubectl scale --replicas=10 deployment/nginx-to-scaleout

> helm install --debug --dry-run --name workshop .

> kubectl get pods

> helm status workshop

Cool way to get the service url from svc command

> kubectl get svc ecsdemo-frontend -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"; echo

Go to the explorer to see if it works, it can take a few minutes.

Introduce failure, for example change the name of the image in values.yaml

> helm upgrade workshop .

> helm history workshop

> helm rollback workshop 1hel

> helm status workshop

Clean up and remember to fix the error introduced in your file.

> helm delete workshop


# Custom Health Checks

Liveness:

> kubectl apply -f liveness-app.yaml

> kubectl describe pod liveness-app

> kubectl exec -it liveness-app -- /bin/kill -s SIGUSR1 1

> kubectl describe pod liveness-app


Readiness:

>kubectl apply -f readiness-deployment.yaml

> kubectl describe deployment readiness-deployment | grep Replicas:

Introduce failure

> kubectl exec -it <YOUR-READINESS-POD-NAME> -- rm /tmp/healthy

> kubectl get pods -l app=readiness-deployment

Fix

> kubectl exec -it <YOUR-READINESS-POD-NAME> -- touch /tmp/healthy


# Deploy the Metrics Server

Method 1: Works but gives unknown for the target CPU when getting hpa

Reference. eksworkshop.com

helm install stable/metrics-server \
    --name metrics-server \
    --version 2.0.4 \
    --namespace metrics

In a few minutes you should be able to list metrics using the following:

kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"

Verify deployment is running

kubectl get deployment metrics-server -n kube-system

helm del --purge metrics-server


# Method 2

Reference:

https://aws.amazon.com/es/premiumsupport/knowledge-center/eks-metrics-server-pod-autoscaler/



> git clone https://github.com/kubernetes-incubator/metrics-server.git

> cd metrics-server/

> kubectl create -f deploy/1.8+/


# Edit metric-server deployment to add the flags

kubectl edit deploy -n kube-system metrics-server

spec:
  containers:
  - args:
    - --kubelet-insecure-tls
    - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
    image: k8s.gcr.io/metrics-server-amd64:v0.3.6

Does this step need to go:

> kubectl apply -f metrics-server-0.3.6/deploy/1.8+/



# Verify metric-server is running correctly

Verify deployment is running

> kubectl get deployment metrics-server -n kube-system

Confirm the Metrics API is available

> kubectl get apiservice v1beta1.metrics.k8s.io -o yaml

> kubectl get pods -n kube-system | grep metrics-server

> kubectl describe pods -n kube-system

> kubectl logs -n kube-system --since=1h metrics-server-596d74f577-4sfsh

Typical error: Unable to fully collect metrics: unable to fully scrape metrics from source kubelet_summary




# Deploy a Sample App

> kubectl run php-apache --image=k8s.gcr.io/hpa-example --requests=cpu=200m --expose --port=80

# Clean Up

> kubectl delete deployment php-apache
> kubectl delete svc php-apache



# Create a HPA resource

> kubectl get hpa

!!!! This command returns unknown on target metric -> see method 2 to deploy metrics

> kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10

This command should not return unknown for target CPU after a couple of minutes, if it happens look for the edit in the metric server deployment section.

> kubectl get hpa -w


Create new container to test:

> kubectl run -i --tty load-generator --image=busybox /bin/sh

To re-attach

> kubectl attach load-generator-7fbcc7489f-nckbd -c load-generator -i -t

Run the following loop on the container shell

> while true; do wget -q -O - http://php-apache; done



# Configure the Cluster Autoscaler

Get in from working nodes in EKS and edit it in cluster_autoscaler.yaml

command:
  - ./cluster-autoscaler
  - --v=4
  - --stderrthreshold=info
  - --cloud-provider=aws
  - --skip-nodes-with-local-storage=false
  - --nodes=2:8:<AUTOSCALING GROUP NAME>


aws iam put-role-policy --role-name $ROLE_NAME --policy-name ASG-Policy-For-Worker --policy-document file://~/Programs/Terraform/kube-cluster-sample/eksdemo/asg_policy/k8s-asg-policy.json

Validate that the policy is attached to the role

aws iam get-role-policy --role-name $ROLE_NAME --policy-name ASG-Policy-For-Worker

kubectl apply -f cluster-autoscaler/cluster_autoscaler.yml


kubectl apply -f cluster-autoscaler/nginx.yaml


From de aws console edit the nodes autoscaling group to allow launch configuration.


ISSUES nodes don't scale down after decreasing replica set.

kubectl scale --replicas=10 deployment/nginx-to-scaleout

# Clean Up


aws iam delete-role-policy --role-name $ROLE_NAME --policy-name ASG-Policy-For-Worker
kubectl delete -f cluster-autoscaler/cluster_autoscaler.yml
kubectl delete -f cluster-autoscaler/nginx.yaml
kubectl delete hpa,svc php-apache
kubectl delete deployment php-apache load-generator


# RBAC

 8260  kubectl create namespace rbac-test
 8261  kubectl create deploy nginx --image=nginx -n rbac-test
 8262  kubectl get all -n rbac-tes



> aws iam list-users

If it rbac-user doesn't exist, create it.

> aws iam create-user --user-name rbac-user
> aws iam create-access-key --user-name rbac-user | tee /tmp/create_output.json



aws iam list-access-keys --user-name rbac-user

export AWS_SECRET_ACCESS_KEY=$(cat /tmp/create_output.json | jq '.AccessKey.SecretAccessKey')
export AWS_ACCESS_KEY_ID=$(cat /tmp/create_output.json | jq '.AccessKey.AccessKeyId')

MUST FIX !!!!

- Comas must be stripped for this to work

- rbacuser_cred returns null and therefore changes the user to the cluster admin.


> aws iam get-user --user-name rbac-user | jq '.User.Arn'

> export ACCOUNT_ID=<your_arn_id>

cat << EoF > aws-auth.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: arn:aws:iam::${ACCOUNT_ID}:user/rbac-user
      username: rbac-user
EoF



How to get account ID

> aws iam get-user --user-name rbac-user

{
    "User": {
        "Path": "/",
        "UserName": "rbac-user",
        "UserId": "AIDAQDCE6O66HDM3L7ZMO",
        "Arn": "arn:aws:iam::006587054012:user/rbac-user",
        "CreateDate": "2020-01-07T18:18:30Z"
    }
}



> aws iam get-user --user-name rbac-user

An error occurred (InvalidClientTokenId) when calling the GetUser operation: The security token included in the request is invalid.
 

> kubectl apply -f rbacuser-role.yaml
> kubectl apply -f rbacuser-role-binding.yaml

Verify user identity.

>. rbacuser_creds.sh; aws sts get-caller-identity

If it doesn't change verify that env variables created don't have quote on the values.



Clean UP

>unset AWS_SECRET_ACCESS_KEY
>unset AWS_ACCESS_KEY_ID
>kubectl delete namespace rbac-test
>rm aws-auth.yaml
>rm rbacuser_creds.sh
>rm /tmp/create_output.json
>	rm rbacuser-role.yaml


# IAM ACCESS ROLES

"
Amazon EKS supports IAM Roles for Service Accounts (IRSA) that allows cluster operators to map AWS IAM Roles to Kubernetes Service Accounts.
This provides fine-grained permission management for apps that run on EKS and use other AWS services. These could be apps that use S3, any other data services (RDS, MQ, STS, DynamoDB), or Kubernetes components like AWS ALB Ingress controller or ExternalDNS.
"

Taken from: https://eksctl.io/usage/iamserviceaccounts/

You can easily create IAM Role and Service Account pairs with eksctl.

    NOTE: if you used instance roles, and are considering to use IRSA instead, you shouldn’t mix the two.

Retrieve OpenID Connect issuer URL:

> aws eks describe-cluster --name terraform-eks-demo --query cluster.identity.oidc.issuer --output text

> https://oidc.eks.us-west-2.amazonaws.com/id/255113AE244CEE9FA91EF54AD718E710

Error: command returns no route to host to a public IP, where does it get from?

> eksctl utils associate-iam-oidc-provider --cluster terraform-eks-demo --approve


	

