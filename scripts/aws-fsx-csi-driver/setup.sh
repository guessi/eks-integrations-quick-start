#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
IAM_POLICY_NAME="${IAM_POLICY_NAME_AmazonFsxCsiDriver}"
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME_AmazonFsxCsiDriver}"

echo "[debug] detecting AWS Account ID"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[debug] AWS Account ID: ${AWS_ACCOUNT_ID}"

echo "[debug] detecting chart repo existance"
helm repo list | grep -q 'aws-fsx-csi-driver'

if [ $? -ne 0 ]; then
  echo "[debug] setup chart repo"
  helm repo add aws-fsx-csi-driver https://kubernetes-sigs.github.io/aws-fsx-csi-driver || true
else
  echo "[debug] found chart repo"
fi

echo "[debug] helm repo update"
helm repo update aws-fsx-csi-driver

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
  --region ${AWS_REGION} \
  --approve \
  --override-existing-serviceaccounts

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'aws-fsx-csi-driver/aws-fsx-csi-driver'

echo "[debug] setup aws-fsx-csi-driver/aws-fsx-csi-driver"
helm upgrade \
  --namespace kube-system \
  --install aws-fsx-csi-driver \
  aws-fsx-csi-driver/aws-fsx-csi-driver \
    --set controller.serviceAccount.create=false \
    --set controller.serviceAccount.name=${SERVICE_ACCOUNT_NAME} \
    --set image.repository=public.ecr.aws/fsx-csi-driver/aws-fsx-csi-driver

echo "[debug] listing installed"
helm list --all-namespaces --filter aws-fsx-csi-driver
