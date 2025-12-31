#!/usr/bin/env bash

#https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html
#https://github.com/aws/eks-charts#eks-charts

#https://memory-alpha.fandom.com/wiki/Portal:Main
#https://cert-manager.io/docs/installation/helm/

export EKS_CLUSTER_NAME='starbase'

#######################################
#Create a kubeconfig for Amazon EKS - Amazon EKS<https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html>
# aws eks --region us-east-1 update-kubeconfig --name starbase --kubeconfig ~/.kube/starbase
#######################################

#aws eks describe-cluster --name starbase --query cluster.resourcesVpcConfig.clusterSecurityGroupId
#pip3 install ansible-runner
#pip3 install ansible-modules-hashivault
#    - import_playbook: webservers.yml

#######################################
##Amazon EBS CSI driver
#https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
#https://github.com/kubernetes-sigs/aws-ebs-csi-driver
##Get sample policy
#######################################
##curl -o example-iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/v1.0.0/docs/example-iam-policy.json
##Create the policy.
#aws iam create-policy \
#    --policy-name AmazonEKS_EBS_CSI_Driver_Policy \
#    --policy-document file:///Users/sdconrox/workplace/com.sdconrox/starbase/ebs-csi-iam-policy.json
#sleep 1
#eksctl utils associate-iam-oidc-provider --region=us-east-1 --cluster=starbase --approve
#sleep 1
##Create an IAM role and attach the IAM policy to it.
#eksctl create iamserviceaccount \
#    --name ebs-csi-controller-sa \
#    --namespace kube-system \
#    --cluster starbase \
#    --attach-policy-arn arn:aws:iam::832481759427:policy/AmazonEKS_EBS_CSI_Driver_Policy \
#    --approve \
#    --override-existing-serviceaccounts
#sleep 1
##Retrieve the ARN of the created role and note the returned value
#aws cloudformation describe-stacks \
#    --stack-name eksctl-starbase-addon-iamserviceaccount-kube-system-ebs-csi-controller-sa \
#    --query='Stacks[].Outputs[?OutputKey==`Role1`].OutputValue' \
#    --output text
#sleep 1
##arn:aws:iam::832481759427:role/eksctl-starbase-addon-iamserviceaccount-kube-Role1-1BO67MKESR5ZW
##Deploy
##Add the aws-ebs-csi-driver Helm repository
#helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
#helm repo update
#sleep 1
##Install a release of the driver using the Helm chart. https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
#helm upgrade -install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
#    --namespace kube-system \
#    --set image.repository=602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/aws-ebs-csi-driver \
#    --set enableVolumeResizing=true \
#    --set enableVolumeSnapshot=true \
#    --set controller.serviceAccount.create=false \
#    --set controller.serviceAccount.name=ebs-csi-controller-sa
#######################################

#helm repo add jetstack https://charts.jetstack.io
#helm install \
#  cert-manager jetstack/cert-manager \
#  --namespace cert-manager \
#  --create-namespace \
#  --version v1.5.3 \
#  --set prometheus.enabled=false \  # Example: disabling prometheus using a Helm parameter
#  --set webhook.timeoutSeconds=4s   # Example: changing the wehbook timeout using a Helm parameter

#ansible-playbook -i inventory playbooks/starbase.yml
ansible-playbook playbooks/starbase.yml


