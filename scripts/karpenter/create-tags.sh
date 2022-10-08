#!/usr/bin/env bash

CLUSTER_NAME="eks-demo"

TARGET_RESOURCES=(
  "subnet-XXXXXXXXXXXXXXXXX"
  "subnet-XXXXXXXXXXXXXXXXX"
  "sg-XXXXXXXXXXXXXXXXX"
)

for TARGET_RESOURCE in ${TARGET_RESOURCES[@]}; do
  aws ec2 create-tags \
    --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}" \
    --resources "${TARGET_RESOURCE}"
done
