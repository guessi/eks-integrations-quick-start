#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
IAM_POLICY_NAME="${IAM_POLICY_NAME_AWSLoadBalancerController}"
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME_AwsLoadBalancerController}"

# CHART VERSION	APP VERSION
# ---------------------------
# 1.6.1        	v2.6.1 (recommend)
# 1.6.0        	v2.6.0
# 1.5.5        	v2.5.4
# 1.5.4        	v2.5.3
# 1.5.3        	v2.5.2
# 1.5.2        	v2.5.1
# 1.5.1        	v2.5.1
# 1.5.0        	v2.5.0
# 1.4.8        	v2.4.7
# 1.4.7        	v2.4.6
# 1.4.6        	v2.4.5
# 1.4.5        	v2.4.4
# 1.4.4        	v2.4.3
# 1.4.3        	v2.4.2
# 1.4.2        	v2.4.2
# 1.4.1        	v2.4.1
# 1.4.0        	v2.4.0
# 1.3.3        	v2.3.1
# 1.3.2        	v2.3.0
# 1.3.1        	v2.3.0

# Kubernetes version requirements
# * AWS Load Balancer Controller v2.0.0~v2.1.3 requires Kubernetes 1.15+
# * AWS Load Balancer Controller v2.2.0~v2.3.1 requires Kubernetes 1.16-1.21
# * AWS Load Balancer Controller v2.4.0+ requires Kubernetes 1.19+
# * AWS Load Balancer Controller v2.5.0+ requires Kubernetes 1.22+
#
# ref: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/deploy/installation/#supported-kubernetes-versions

APP_VERSION="v2.6.1"
CHART_VERSION="1.6.1"

echo "[debug] detecting AWS Account ID"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[debug] AWS Account ID: ${AWS_ACCOUNT_ID}"

echo "[debug] detecting VPC ID"
export VPC_ID=$(aws eks describe-cluster --name ${EKS_CLUSTER_NAME} --query 'cluster.resourcesVpcConfig.vpcId' --output text --region ${AWS_REGION})
echo "[debug] VPC ID: ${VPC_ID}"

echo "[debug] detecting chart repo existance"
helm repo list | grep -q 'eks-charts'

if [ $? -ne 0 ]; then
  echo "[debug] setup chart repo"
  helm repo add eks https://aws.github.io/eks-charts || true
else
  echo "[debug] found chart repo"
fi

echo "[debug] helm repo update"
helm repo update eks

echo "[debug] detecting IAM policy existance"
aws iam list-policies --query "Policies[].[PolicyName,UpdateDate]" --output text | grep "${IAM_POLICY_NAME}"

if [ $? -ne 0 ]; then
  echo "[debug] IAM policy existance not found, creating"
  aws iam create-policy \
    --policy-name ${IAM_POLICY_NAME} \
    --policy-document file://policy.json
else
  echo "[debug] IAM policy existed"
fi

echo "[debug] creating IAM Roles for Service Accounts"
eksctl create iamserviceaccount \
  --namespace kube-system \
  --region ${AWS_REGION} \
  --cluster ${EKS_CLUSTER_NAME} \
  --name ${SERVICE_ACCOUNT_NAME} \
  --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME} \
  --approve \
  --override-existing-serviceaccounts

echo "[debug] creating Custom Resource Definition (CRDs)"
kubectl apply -k "github.com/aws/eks-charts//stable/aws-load-balancer-controller/crds?ref=master"

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'aws-load-balancer-controller'

# TODO: nice to have regional image setup
echo "[debug] setup eks/aws-load-balancer-controller"
helm upgrade \
  --namespace kube-system \
  --install aws-load-balancer-controller \
  --version ${CHART_VERSION} \
  eks/aws-load-balancer-controller \
    --set serviceAccount.create=false \
    --set serviceAccount.name=${SERVICE_ACCOUNT_NAME} \
    --set image.repository=public.ecr.aws/eks/aws-load-balancer-controller \
    --set image.tag=${APP_VERSION} \
    --set clusterName=${EKS_CLUSTER_NAME} \
    --set region=${AWS_REGION} \
    --set vpcId=${VPC_ID}

echo "[debug] listing installed"
helm list --all-namespaces --filter aws-load-balancer-controller
