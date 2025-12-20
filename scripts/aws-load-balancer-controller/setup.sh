#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
IAM_POLICY_NAME="${IAM_POLICY_NAME_AWSLoadBalancerController}"
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME_AwsLoadBalancerController}"

# CHART VERSION APP VERSION
# ---------------------------
# 1.17.0        v2.17.0 (recommend)
# 1.16.0        v2.16.0 (preferred version for 2.16.x)
# 1.15.0        v2.15.0 (preferred version for 2.15.x)
# 1.14.1        v2.14.1 (preferred version for 2.14.x)

# Kubernetes version requirements
# - https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.17/deploy/installation/#supported-kubernetes-versions

APP_VERSION="v2.17.0"
CHART_VERSION="1.17.0"

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
  echo "[debug] IAM policy existed, checking difference"

  IAM_POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`'${IAM_POLICY_NAME}'`].Arn' --output text)
  RUNNING_VERSION=$(aws iam get-policy --policy-arn ${IAM_POLICY_ARN} --query 'Policy.DefaultVersionId' --output text)
  aws iam get-policy-version --policy-arn ${IAM_POLICY_ARN} --version-id ${RUNNING_VERSION} --query 'PolicyVersion.Document' --output json > running-policy.json

  diff policy.json running-policy.json
  if [ $? -ne 0 ]; then
    aws iam create-policy-version \
      --policy-arn ${IAM_POLICY_ARN} \
      --policy-document file://policy.json \
      --set-as-default
  else
    echo "[debug] policy update skipped, no update required"
  fi

  echo "[debug] cleanup running-policy.json"
  rm -vf running-policy.json
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
kubectl apply -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml

GATEWAY_API_VERSION="v1.2.0"
echo "[debug] creating Custom Resource Definition (CRDs) for Gateway API ${GATEWAY_API_VERSION}"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml
# kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/experimental-install.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'aws-load-balancer-controller'

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
    --set vpcId=${VPC_ID} \
    --set controllerConfig.featureGates.NLBGatewayAPI=true \
    --set controllerConfig.featureGates.ALBGatewayAPI=true

echo "[debug] listing installed"
helm list --all-namespaces --filter aws-load-balancer-controller
