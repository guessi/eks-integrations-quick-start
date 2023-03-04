#!/usr/bin/env bash

AWS_REGION="us-east-1"
EKS_CLUSTER_NAME="eks-demo"

VPC_ID=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" --query 'cluster.resourcesVpcConfig.vpcId' --output text --no-cli-pager)
echo "[debug] ${VPC_ID}"

PRIVATE_SUBNET_IDS=($(aws ec2 describe-subnets --region "${AWS_REGION}" --filter "Name=state,Values=available" "Name=vpc-id,Values=${VPC_ID}" "Name=tag:kubernetes.io/role/internal-elb,Values=1" --query 'Subnets[*]["SubnetId"][]' --output text --no-cli-pager))
echo "[debug] ${PRIVATE_SUBNET_IDS[@]}"

for TARGET in ${PRIVATE_SUBNET_IDS[@]}; do
  echo "[debug] Creating resource tag for \"${TARGET}\""
  aws ec2 create-tags \
    --tags "Key=karpenter.sh/discovery,Value=${EKS_CLUSTER_NAME}" \
    --resources "${TARGET}"
done

echo
echo "*** YOU WILL STILL NEED TO CREATE TAG FOR SECURITY GROUP FOR NODES ***"
echo
