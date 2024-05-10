#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
IAM_POLICY_NAME="VPCLatticeControllerIAMPolicy"
SERVICE_ACCOUNT_NAME="gateway-api-controller"

# ref: https://github.com/aws/aws-application-networking-k8s/blob/release-v1.0.5/docs/guides/deploy.md

APP_VERSION="1.0.5"
CHART_VERSION="1.0.5"

echo "[debug] detecting AWS Account ID"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[debug] AWS Account ID: ${AWS_ACCOUNT_ID}"

echo "[debug] detecting namespace existance"
kubectl get namespace | grep -q 'aws-application-networking-system'
if [ $? -ne 0 ]; then
  kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/deploy-namesystem.yaml
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

echo "[debug] setup gateway-api-controller/aws-application-networking-system"
helm upgrade \
  --namespace aws-application-networking-system \
  --create-namespace \
  --install gateway-api-controller \
  --version v${CHART_VERSION} \
  oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart \
    --set serviceAccount.create=false \
    --set serviceAccount.name=${SERVICE_ACCOUNT_NAME} \
    --set fullnameOverride="gateway-api-controller" \
    --set awsregion=${AWS_REGION} \
    --set clusterName=${EKS_CLUSTER_NAME} \
    --set log.level=info \
    --wait
   # When specified, the controller will automatically create a service network with the name.
   # --set=defaultServiceNetwork=my-hotel

echo "[debug] listing installed"
helm list --all-namespaces --filter gateway-api-controller

echo "[debug] setup GatewayClass"
if ! kubectl get GatewayClass | grep -q 'amazon-vpc-lattice'; then
  echo "[debug] GatewayClass 'amazon-vpc-lattice' not found, creating"
  kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/gatewayclass.yaml
  kubectl get GatewayClass
else
  echo "[debug] GatewayClass 'amazon-vpc-lattice' existed"
fi
