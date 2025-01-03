#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
IAM_POLICY_NAME="${IAM_POLICY_NAME_AppMeshController}"
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME_AppMeshController}"

# CHART VERSION APP VERSION
# ---------------------------
# 1.13.1        1.13.1

APP_VERSION="1.13.1"
CHART_VERSION="1.13.1"

echo "[debug] detecting AWS Account ID"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[debug] AWS Account ID: ${AWS_ACCOUNT_ID}"

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
  --attach-policy-arn  arn:aws:iam::aws:policy/AWSCloudMapFullAccess,arn:aws:iam::aws:policy/AWSAppMeshFullAccess \
  --approve \
  --override-existing-serviceaccounts

echo "[debug] creating Custom Resource Definition (CRDs)"
kubectl apply -k "https://github.com/aws/eks-charts/stable/appmesh-controller/crds?ref=master"

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
    --set region=${AWS_REGION}

echo "[debug] listing installed"
helm list --all-namespaces --filter appmesh-controller

echo "[debug] create iam policy for sample scenario"
sed -e 's/{{ REGION }}/'${AWS_REGION}'/g' -e 's/{{ AWS_ACCOUNT_ID }}/'${AWS_ACCOUNT_ID}'/g' proxy-auth-template.json > proxy-auth.json
aws iam create-policy --policy-name AppMesh-sample-policy --policy-document file://proxy-auth.json

echo "[debug] create servcie account for sample scenario"
eksctl create iamserviceaccount \
    --cluster ${EKS_CLUSTER_NAME} \
    --namespace my-apps \
    --name my-service \
    --attach-policy-arn  arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AppMesh-sample-policy \
    --override-existing-serviceaccounts \
    --approve
