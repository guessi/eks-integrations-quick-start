#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
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

echo "[debug] creating IAM Roles for Service Accounts"
eksctl create iamserviceaccount \
  --namespace kube-system \
  --region ${AWS_REGION} \
  --cluster ${EKS_CLUSTER_NAME} \
  --name ${SERVICE_ACCOUNT_NAME} \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonFSxFullAccess \
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
    --set controller.serviceAccount.name=${SERVICE_ACCOUNT_NAME}

echo "[debug] listing installed"
helm list --all-namespaces --filter aws-fsx-csi-driver
