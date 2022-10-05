#!/usr/bin/env bash

AWS_REGION="us-east-1"
EKS_CLUSTER_NAME="eks-demo"
POLICY_NAME="AWSAppMeshK8sControllerIAMPolicy"
SERVICE_ACCOUNT_NAME="appmesh-controller"

# CHART VERSION	APP VERSION
# ---------------------------
# 1.7.0        	1.7.0
# 1.6.0        	1.6.0
# 1.5.1        	1.5.1
# 1.5.0        	1.5.0
# 1.4.9        	1.4.3
# 1.4.8        	1.4.3
# 1.4.7        	1.4.3
# 1.4.6        	1.4.3
# 1.4.5        	1.4.3
# 1.4.4        	1.4.2
# 1.4.2        	1.4.1
# 1.4.1        	1.4.1
# 1.4.0        	1.4.0
# 1.3.2        	1.3.0
# 1.3.1        	1.3.0
# 1.3.0        	1.3.0
# 1.2.2        	1.2.1
# 1.2.1        	1.2.1

APP_VERSION="1.7.0"
CHART_VERSION="1.7.0"
CONTROLLER_IMAGE_TAG="v1.7.0"
SIDECAR_IMAGE_TAG="v1.22.2.1-prod"
INIT_IMAGE_TAG="v6-prod"

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
aws iam list-policies --query "Policies[].[PolicyName,UpdateDate]" --output text | grep "${POLICY_NAME}"

if [ $? -ne 0 ]; then
  echo "[debug] IAM policy existance not found, creating"
  aws iam create-policy \
    --policy-name ${POLICY_NAME} \
    --policy-document file://policy.json
else
  echo "[debug] IAM policy existed"
fi

echo "[debug] detecting namespace existance"
kubectl get namespace | grep -q 'appmesh-system'

if [ $? -ne 0 ]; then
  echo "[debug] creating namespace"
  kubectl create namespace appmesh-system
else
  echo "[debug] found namespace"
fi

echo "[debug] creating IAM Roles for Service Accounts"
eksctl create iamserviceaccount \
  --namespace appmesh-system \
  --region ${AWS_REGION} \
  --cluster ${EKS_CLUSTER_NAME} \
  --name ${SERVICE_ACCOUNT_NAME} \
  --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME} \
  --approve \
  --override-existing-serviceaccounts

echo "[debug] creating Custom Resource Definition (CRDs)"
kubectl apply -k "github.com/aws/eks-charts/stable/appmesh-controller//crds?ref=master"

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'appmesh-controller'

# TODO: nice to have regional image setup
echo "[debug] setup eks/appmesh-controller"
helm upgrade \
  --namespace appmesh-system \
  --install appmesh-controller \
  --version ${CHART_VERSION} \
  eks/appmesh-controller \
    --set serviceAccount.create=false \
    --set serviceAccount.name=${SERVICE_ACCOUNT_NAME} \
    --set image.repository=602401143452.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/appmesh-controller \
    --set image.tag=${CONTROLLER_IMAGE_TAG} \
    --set sidecar.image.repository=602401143452.dkr.ecr.${AWS_REGION}.amazonaws.com/aws-appmesh-envoy \
    --set sidecar.image.tag=${SIDECAR_IMAGE_TAG} \
    --set init.image.repository=602401143452.dkr.ecr.${AWS_REGION}.amazonaws.com/aws-appmesh-proxy-route-manager \
    --set init.image.tag=${INIT_IMAGE_TAG} \
    --set region=${AWS_REGION}

# the attributes above are copied from https://github.com/aws/eks-charts/blob/v0.0.108/stable/appmesh-controller/values.yaml (v0.0.108 is mapped to CHART_VERSION v1.7.0)
# whenever you changed the CHART_VERSION or APP_VERSION, you should double confirm whether the version is you would like to install.
# and don't foget the chagne the account number "602401143452" above if you are not running with "us-east-1".
# ref: https://docs.aws.amazon.com/app-mesh/latest/userguide/getting-started-kubernetes.html#install-controller

echo "[debug] listing installed"
helm list --all-namespaces --filter appmesh-controller
