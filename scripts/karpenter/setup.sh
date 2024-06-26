#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
IAM_POLICY_NAME="${IAM_POLICY_NAME_Karpenter}"
IAM_ROLE_NAME="${IAM_ROLE_NAME_Karpenter}"
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME_Karpenter}"

# Before upgrade, you should always check latest upgrade guide:
# - https://karpenter.sh/preview/concepts/nodeclasses/
# - https://karpenter.sh/preview/upgrade-guide/
# - https://karpenter.sh/v0.32/upgrading/v1beta1-migration/

# CHART VERSION	            APP VERSION
# ----------------------------------------
# karpenter-v0.37.0        	0.37.0   # ref: https://github.com/aws/karpenter/releases/tag/v0.37.0 (recommend)
# karpenter-v0.36.2        	0.36.2   # ref: https://github.com/aws/karpenter/releases/tag/v0.36.2
# karpenter-v0.35.5        	0.35.5   # ref: https://github.com/aws/karpenter/releases/tag/v0.35.5

APP_VERSION="0.37.0"
CHART_VERSION="0.37.0"

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
curl -fsSL "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${APP_VERSION}/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml" -O

if [ ! -f "cloudformation.yaml" ]; then
  echo "Failed to download cloudformation.yaml"
  exit 1
fi

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
  --role-name "${IAM_ROLE_NAME}" \
  --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME} \
  --approve \
  --override-existing-serviceaccounts

echo "[debug] creating Custom Resource Definition (CRDs)"
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter/v${CHART_VERSION}/pkg/apis/crds/karpenter.sh_nodepools.yaml
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter/v${CHART_VERSION}/pkg/apis/crds/karpenter.sh_nodeclaims.yaml
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter/v${CHART_VERSION}/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'karpenter'

# https://github.com/aws/karpenter/pull/3880
echo "[debug] ensure helm registry is logout"
helm registry logout public.ecr.aws

echo "[debug] setup karpenter/karpenter"

helm upgrade \
  --namespace karpenter \
  --create-namespace \
  --install karpenter \
  --version ${CHART_VERSION} \
  oci://public.ecr.aws/karpenter/karpenter \
    --set serviceAccount.create=false \
    --set serviceAccount.name=${SERVICE_ACCOUNT_NAME} \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME}" \
    --set settings.clusterName=${EKS_CLUSTER_NAME} \
    --set settings.interruptionQueue=${EKS_CLUSTER_NAME} \
    --set settings.clusterEndpoint=${CLUSTER_ENDPOINT} \
    --set controller.resources.requests.cpu=500m \
    --set controller.resources.requests.memory=500Mi \
    --set controller.resources.limits.cpu=1 \
    --set controller.resources.limits.memory=1Gi \
    --wait

echo "[debug] listing installed"
helm list --all-namespaces --filter karpenter

echo "[debug] post-install reminders"
echo "Before applying CRDs, you should check for karpenter discovery tags definitions."
