#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"

VPC_ID=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" --query 'cluster.resourcesVpcConfig.vpcId' --output text --no-cli-pager)
echo "[debug] ${VPC_ID}"

PUBLIC_SUBNET_IDS=($(aws ec2 describe-subnets --region "${AWS_REGION}" --filter "Name=state,Values=available" "Name=vpc-id,Values=${VPC_ID}" "Name=tag:kubernetes.io/role/elb,Values=1" --query 'Subnets[*]["SubnetId"][]' --output text --no-cli-pager))
echo "[debug] Public Subnets: ${PUBLIC_SUBNET_IDS[@]}"

PRIVATE_SUBNET_IDS=($(aws ec2 describe-subnets --region "${AWS_REGION}" --filter "Name=state,Values=available" "Name=vpc-id,Values=${VPC_ID}" "Name=tag:kubernetes.io/role/internal-elb,Values=1" --query 'Subnets[*]["SubnetId"][]' --output text --no-cli-pager))
echo "[debug] Private Subnets: ${PRIVATE_SUBNET_IDS[@]}"

for TARGET in ${PUBLIC_SUBNET_IDS[@]}; do
  echo "[debug] Removing resource tag for \"${TARGET}\""
  aws ec2 delete-tags \
    --tags "Key=karpenter.sh/discovery,Value=${EKS_CLUSTER_NAME}" \
    --resources "${TARGET}"
done
for TARGET in ${PRIVATE_SUBNET_IDS[@]}; do
  echo "[debug] Creating resource tag for \"${TARGET}\""
  aws ec2 create-tags \
    --tags "Key=karpenter.sh/discovery,Value=${EKS_CLUSTER_NAME}" \
    --resources "${TARGET}"
done

echo
echo "*** YOU WILL STILL NEED TO CREATE TAG FOR SECURITY GROUP FOR NODES ***"
echo
