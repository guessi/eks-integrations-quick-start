#!/usr/bin/env bash

AWS_REGION="us-east-1"
EKS_CLUSTER_NAME="eks-demo"
POLICY_NAME="KarpenterControllerPolicy-${EKS_CLUSTER_NAME}"
SERVICE_ACCOUNT_NAME="karpenter"
ROLE_NAME="${EKS_CLUSTER_NAME}-karpenter"

# Before upgrade, you should always check latest upgrade guide:
# - https://karpenter.sh/preview/upgrade-guide/

# CHART VERSION	             APP VERSION
# ----------------------------------------
# karpenter-v0.24.0        	0.24.0   # ref: https://github.com/aws/karpenter/releases/tag/v0.24.0 (recommend)
# karpenter-v0.23.0        	0.23.0   # ref: https://github.com/aws/karpenter/releases/tag/v0.23.0

APP_VERSION="0.24.0"
CHART_VERSION="0.24.0"

echo "[debug] detecting AWS Account ID"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[debug] AWS Account ID: ${AWS_ACCOUNT_ID}"

echo "[debug] detecting cluster endpoint"
export CLUSTER_ENDPOINT="$(aws eks describe-cluster --name ${EKS_CLUSTER_NAME} --query "cluster.endpoint" --output text --region ${AWS_REGION})"
echo "[debug] CLUSTER ENDPOINT: ${CLUSTER_ENDPOINT}"

echo "[debug] detecting namespace existance"
kubectl get namespace | grep -q 'karpenter'
if [ $? -ne 0 ]; then
  kubectl create namespace karpenter
else
  echo "[debug] namespace existed"
fi

echo "[debug] setup IAM resources"
curl -fsSL "https://karpenter.sh/v${APP_VERSION}/getting-started/getting-started-with-eksctl/cloudformation.yaml" -O

aws cloudformation deploy \
  --stack-name "Karpenter-${EKS_CLUSTER_NAME}" \
  --template-file cloudformation.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${EKS_CLUSTER_NAME}"

rm -vf cloudformation.yaml # cleanup

echo "[debug] creating mapRole for aws-auth"
eksctl create iamidentitymapping \
  --username "system:node:{{EC2PrivateDNSName}}" \
  --region ${AWS_REGION} \
  --cluster "${EKS_CLUSTER_NAME}" \
  --arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${EKS_CLUSTER_NAME}" \
  --group "system:bootstrappers" \
  --group "system:nodes"

echo "[debug] creating IAM Roles for Service Accounts"
eksctl create iamserviceaccount \
  --namespace karpenter \
  --region ${AWS_REGION} \
  --cluster ${EKS_CLUSTER_NAME} \
  --name ${SERVICE_ACCOUNT_NAME} \
  --role-name "${ROLE_NAME}" \
  --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME} \
  --approve \
  --override-existing-serviceaccounts

echo "[debug] creating Custom Resource Definition (CRDs)"
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter/v${CHART_VERSION}/pkg/apis/crds/karpenter.sh_provisioners.yaml
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter/v${CHART_VERSION}/pkg/apis/crds/karpenter.k8s.aws_awsnodetemplates.yaml

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'karpenter'

echo "[debug] setup karpenter/karpenter"

helm upgrade \
  --namespace karpenter \
  --create-namespace \
  --install karpenter \
  --version v${CHART_VERSION} \
  oci://public.ecr.aws/karpenter/karpenter \
    --set serviceAccount.create=false \
    --set serviceAccount.name=${SERVICE_ACCOUNT_NAME} \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}" \
    --set settings.aws.clusterName=${EKS_CLUSTER_NAME} \
    --set settings.aws.clusterEndpoint=${CLUSTER_ENDPOINT} \
    --set settings.aws.defaultInstanceProfile=KarpenterNodeInstanceProfile-${EKS_CLUSTER_NAME} \
    --set settings.aws.interruptionQueueName=${EKS_CLUSTER_NAME} \
    --wait

echo "[debug] listing installed"
helm list --all-namespaces --filter karpenter
