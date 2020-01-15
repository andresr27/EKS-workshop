CONSOLE




# Set up Access to the cluster for tiller

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







# HPA

Deploy the Metrics Server

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


# Deploy metric-server: Delete


> kubectl apply -f metrics-server-0.3.6/deploy/1.8+/


Verify deployment is running

> kubectl get deployment metrics-server -n kube-system


Confirm the Metrics API is available

> kubectl get apiservice v1beta1.metrics.k8s.io -o yaml

> kubectl get pods -n kube-system

> kubectl get pods -n kube-system | grep metrics-server

> kubectl logs -n kube-system --since=1h metrics-server-596d74f577-4sfsh

 unable to fully collect metrics: unable to fully scrape metrics from source kubelet_summary





# Deploy a Sample App

> kubectl run php-apache --image=k8s.gcr.io/hpa-example --requests=cpu=200m --expose --port=80

# Clean Up

> kubectl delete deployment php-apache
> kubectl delete svc php-apache





# Create a HPA resource

> kubectl get hpa

!!!! This command returns unknown on target metric -> see method 2 to deploy metrics

> kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10

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

An error occurred (InvalidClientTokenId) when calling the GetUser operation: The security token included in the request is invalid.
 




