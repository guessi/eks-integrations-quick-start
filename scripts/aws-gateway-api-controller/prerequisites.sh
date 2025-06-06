#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"

echo "[debug] detecting prefix list id for \"com.amazonaws.${AWS_REGION}.vpc-lattice\""
PREFIX_LIST_ID=$(aws ec2 describe-managed-prefix-lists --query "PrefixLists[?PrefixListName=='com.amazonaws.${AWS_REGION}.vpc-lattice'].PrefixListId" | jq -r '.[]')
echo "[debug] ${PREFIX_LIST_ID}"

echo "[debug] detecting prefix list id for \"com.amazonaws.${AWS_REGION}.ipv6.vpc-lattice\""
PREFIX_LIST_ID_IPV6=$(aws ec2 describe-managed-prefix-lists --query "PrefixLists[?PrefixListName=='com.amazonaws.${AWS_REGION}.ipv6.vpc-lattice'].PrefixListId" | jq -r '.[]')echo "[debug] ${PREFIX_LIST_ID_IPV6}"

echo "[debug] detecting cluster security group"
CLUSTER_SG=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --output "json" --region "${AWS_REGION}" | jq -r '.cluster.resourcesVpcConfig.clusterSecurityGroupId')
echo "[debug] ${CLUSTER_SG}"

echo "[debug] prefix is now listed in ${CLUSTER_SG}"
PREFIXES_IN_CLUSTER_SG=$(aws ec2 describe-security-group-rules --filter "Name=group-id,Values=${CLUSTER_SG}" --output "json" --region "${AWS_REGION}" | jq -r '.SecurityGroupRules[] | select(.PrefixListId != null) | .PrefixListId' | xargs)
echo "[debug] ${PREFIXES_IN_CLUSTER_SG}"

if ! echo "${PREFIXES_IN_CLUSTER_SG}" | grep -q "${PREFIX_LIST_ID}"; then
  aws ec2 authorize-security-group-ingress \
    --group-id "${CLUSTER_SG}" \
    --ip-permissions "PrefixListIds=[{PrefixListId=${PREFIX_LIST_ID},Description=\"Allow Prefix List for VPC Lattice (IPv4)\"}],IpProtocol=-1" \
    --region "${AWS_REGION}"
else
  echo "Skip, security rule for VPC Lattice (IPv4) already existed."
fi

if ! echo "${PREFIXES_IN_CLUSTER_SG}" | grep -q "${PREFIX_LIST_ID_IPV6}"; then
  aws ec2 authorize-security-group-ingress \
    --group-id "${CLUSTER_SG}" \
    --ip-permissions "PrefixListIds=[{PrefixListId=${PREFIX_LIST_ID_IPV6},Description=\"Allow Prefix List for VPC Lattice (IPv6)\"}],IpProtocol=-1" \
    --region "${AWS_REGION}"
else
  echo "Skip, security rule for VPC Lattice (IPv6) already existed."
fi
