#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
IAM_POLICY_NAME="${IAM_POLICY_NAME_ClusterAutoScaler}"
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME_ClusterAutoScaler}"

# CHART VERSION	APP VERSION
# ---------------------------
# 9.50.1       	1.33.0

APP_VERSION="v1.33.0"
CHART_VERSION="9.50.1"

# HINT: if there have multiple cluster-autoscaler running under the same cluster, you might need to customize these variables.
NAMESPACE="kube-system"
FULLNAME_OVERRIDE="cluster-autoscaler"

# Supported Versions:
# - https://github.com/kubernetes/autoscaler/releases/tag/cluster-autoscaler-1.33.0
# - https://github.com/kubernetes/autoscaler/releases/tag/cluster-autoscaler-1.32.2
# - https://github.com/kubernetes/autoscaler/releases/tag/cluster-autoscaler-1.31.3
# - https://github.com/kubernetes/autoscaler/releases/tag/cluster-autoscaler-1.30.5

echo "[debug] detecting AWS Account ID"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[debug] AWS Account ID: ${AWS_ACCOUNT_ID}"

echo "[debug] detecting chart repo existance"
helm repo list | grep -q 'autoscaler'

if [ $? -ne 0 ]; then
  echo "[debug] setup chart repo"
  helm repo add autoscaler https://kubernetes.github.io/autoscaler || true
else
  echo "[debug] found chart repo"
fi

echo "[debug] helm repo update"
helm repo update autoscaler

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
fi

echo "[debug] creating IAM Roles for Service Accounts"
eksctl create iamserviceaccount \
  --namespace ${NAMESPACE} \
  --region ${AWS_REGION} \
  --cluster ${EKS_CLUSTER_NAME} \
  --name ${SERVICE_ACCOUNT_NAME} \
  --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME} \
  --approve \
  --override-existing-serviceaccounts

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'cluster-autoscaler'

echo "[debug] setup autoscaler/cluster-autoscaler"
helm upgrade \
  --namespace ${NAMESPACE} \
  --install cluster-autoscaler \
  --version ${CHART_VERSION} \
  autoscaler/cluster-autoscaler \
    --set awsRegion=${AWS_REGION} \
    --set clusterAPIConfigMapsNamespace=${NAMESPACE} \
    --set rbac.serviceAccount.create=false \
    --set rbac.serviceAccount.name=${SERVICE_ACCOUNT_NAME} \
    --set autoDiscovery.clusterName=${EKS_CLUSTER_NAME} \
    --set fullnameOverride="${FULLNAME_OVERRIDE}" \
    --set image.tag="${APP_VERSION}"

echo "[debug] listing installed"
helm list --all-namespaces --filter cluster-autoscaler
