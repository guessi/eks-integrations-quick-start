#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
IAM_POLICY_NAME="VPCLatticeControllerIAMPolicy"
SERVICE_ACCOUNT_NAME="gateway-api-controller"

APP_VERSION="0.0.11"
CHART_VERSION="0.0.11"

echo "[debug] detecting AWS Account ID"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[debug] AWS Account ID: ${AWS_ACCOUNT_ID}"

echo "[debug] detecting namespace existance"
kubectl get namespace | grep -q 'aws-application-networking-system'
if [ $? -ne 0 ]; then
  kubectl create namespace aws-application-networking-system
  kubectl label namespaces aws-application-networking-system control-plane=gateway-api-controller
else
  echo "[debug] namespace existed"
fi

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
  --namespace aws-application-networking-system \
  --region ${AWS_REGION} \
  --cluster ${EKS_CLUSTER_NAME} \
  --name ${SERVICE_ACCOUNT_NAME} \
  --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME} \
  --approve \
  --override-existing-serviceaccounts

echo "[debug] log into Public ECR"
aws ecr-public get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin public.ecr.aws

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'aws-application-networking-system'

echo "[debug] ensure helm registry is logout"
helm registry logout public.ecr.aws

echo "[debug] setup gateway-api-controller/aws-application-networking-system"
helm upgrade \
  --namespace aws-application-networking-system \
  --create-namespace \
  --install gateway-api-controller \
  --version v${CHART_VERSION} \
  oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart \
    --set serviceAccount.create=false \
    --set serviceAccount.name=${SERVICE_ACCOUNT_NAME} \
    --set aws.region=${AWS_REGION} \
    --wait

echo "[debug] listing installed"
helm list --all-namespaces --filter aws-application-networking-system

echo "[debug] setup GatewayClass"
if ! kubectl get GatewayClass | grep -q 'amazon-vpc-lattice'; then
  echo "[debug] GatewayClass 'amazon-vpc-lattice' not found, creating"
  kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/v${APP_VERSION}/examples/gatewayclass.yaml
else
  echo "[debug] GatewayClass 'amazon-vpc-lattice' existed"
fi
