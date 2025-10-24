#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
IAM_POLICY_NAME="VPCLatticeControllerIAMPolicy"
SERVICE_ACCOUNT_NAME="gateway-api-controller"

# ref: https://github.com/aws/aws-application-networking-k8s/blob/v1.1.6/docs/guides/deploy.md

APP_VERSION="1.1.6"
CHART_VERSION="1.1.6"

echo "[debug] detecting AWS Account ID"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[debug] AWS Account ID: ${AWS_ACCOUNT_ID}"

echo "[debug] detecting namespace existance"
kubectl get namespace | grep -q 'aws-application-networking-system'
if [ $? -ne 0 ]; then
  kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/v1.1.6/files/controller-installation/deploy-namesystem.yaml
else
  echo "[debug] namespace existed"
fi

echo "[debug] detecting IAM policy existance"
aws iam list-policies --query "Policies[].[PolicyName,UpdateDate]" --output text | grep "${IAM_POLICY_NAME}"

if [ $? -ne 0 ]; then
  echo "[debug] IAM policy existance not found, creating"
  curl -fsSL https://raw.githubusercontent.com/aws/aws-application-networking-k8s/v1.1.6/files/controller-installation/recommended-inline-policy.json -O
  aws iam create-policy \
    --policy-name ${IAM_POLICY_NAME} \
    --policy-document file://recommended-inline-policy.json
else
  echo "[debug] IAM policy existed, checking difference"

  IAM_POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`'${IAM_POLICY_NAME}'`].Arn' --output text)
  RUNNING_VERSION=$(aws iam get-policy --policy-arn ${IAM_POLICY_ARN} --query 'Policy.DefaultVersionId' --output text)
  aws iam get-policy-version --policy-arn ${IAM_POLICY_ARN} --version-id ${RUNNING_VERSION} --query 'PolicyVersion.Document' --output json > running-policy.json

  diff recommended-inline-policy.json running-policy.json
  if [ $? -ne 0 ]; then
    aws iam create-policy-version \
      --policy-arn ${IAM_POLICY_ARN} \
      --policy-document file://recommended-inline-policy.json \
      --set-as-default
  else
    echo "[debug] policy update skipped, no update required"
  fi
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
  kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/v1.1.6/files/controller-installation/gatewayclass.yaml
  kubectl get GatewayClass
else
  echo "[debug] GatewayClass 'amazon-vpc-lattice' existed"
fi
