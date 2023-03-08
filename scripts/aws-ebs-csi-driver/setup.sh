#!/usr/bin/env bash

AWS_REGION="us-east-1"
EKS_CLUSTER_NAME="eks-demo"
POLICY_NAME="AmazonEKS_EBS_CSI_Driver_Policy"
SERVICE_ACCOUNT_NAME="ebs-csi-controller"

echo "[debug] detecting AWS Account ID"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[debug] AWS Account ID: ${AWS_ACCOUNT_ID}"

echo "[debug] detecting chart repo existance"
helm repo list | grep -q 'aws-ebs-csi-driver'

if [ $? -ne 0 ]; then
  echo "[debug] setup chart repo"
  helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver || true
else
  echo "[debug] found chart repo"
fi

echo "[debug] helm repo update"
helm repo update aws-ebs-csi-driver

echo "[debug] creating IAM Roles for Service Accounts"
eksctl create iamserviceaccount \
  --namespace kube-system \
  --region ${AWS_REGION} \
  --cluster ${EKS_CLUSTER_NAME} \
  --name ${SERVICE_ACCOUNT_NAME} \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --override-existing-serviceaccounts

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'aws-ebs-csi-driver/aws-ebs-csi-driver'

# TODO: nice to have regional image setup
echo "[debug] setup aws-ebs-csi-driver/aws-ebs-csi-driver"
helm upgrade \
  --namespace kube-system \
  --install aws-ebs-csi-driver \
  aws-ebs-csi-driver/aws-ebs-csi-driver \
    --set controller.serviceAccount.create=false \
    --set controller.serviceAccount.name=${SERVICE_ACCOUNT_NAME} \
    --set image.repository=public.ecr.aws/ebs-csi-driver/aws-ebs-csi-driver

echo "[debug] listing installed"
helm list --all-namespaces --filter aws-ebs-csi-driver
