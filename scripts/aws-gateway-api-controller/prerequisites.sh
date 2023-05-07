#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"

echo "[debug] detecting prefix list id for \"com.amazonaws.${AWS_REGION}.vpc-lattice\""
PREFIX_LIST_ID=$(aws ec2 describe-managed-prefix-lists --query "PrefixLists[?PrefixListName=="\'com.amazonaws.${AWS_REGION}.vpc-lattice\'"].PrefixListId" --output text)
echo "[debug] ${PREFIX_LIST_ID}"

echo "[debug] detecting managed prefix list entries for ${PREFIX_LIST_ID}"
MANAGED_PREFIX=$(aws ec2 get-managed-prefix-list-entries --prefix-list-id ${PREFIX_LIST_ID} --query 'Entries[0].Cidr' --output text)
echo "[debug] ${MANAGED_PREFIX}"

echo "[debug] detecting cluster security group"
CLUSTER_SG=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
echo "[debug] ${CLUSTER_SG}"

if ! aws ec2 describe-security-group-rules --filter "Name=group-id,Values=${CLUSTER_SG}" --query "SecurityGroupRules[].CidrIpv4" --output text | grep -q "${MANAGED_PREFIX}"; then
  aws ec2 authorize-security-group-ingress --group-id "${CLUSTER_SG}" --cidr "${MANAGED_PREFIX}" --protocol -1
else
  echo "Skip, security rule for VPC Lattice already existed."
fi
