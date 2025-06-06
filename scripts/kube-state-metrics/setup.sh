#!/usr/bin/env bash

source $(pwd)/../config.sh

AWS_REGION="${EKS_CLUSTER_REGION}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
ADDON_NAME="kube-state-metrics"

echo "[debug] detecting AWS Account ID"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[debug] AWS Account ID: ${AWS_ACCOUNT_ID}"

CLUSTER_VERSION=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" --output "json" | jq -r '.cluster.version')
echo "[debug] cluster version: ${CLUSTER_VERSION}"

LATEST_ADD_VERSION=$(aws eks describe-addon-versions --addon-name "${ADDON_NAME}" --publishers "eks" --owners "community" --output "json" --kubernetes-version "${CLUSTER_VERSION}" | jq '.addons[].addonVersions[].addonVersion' -r | sort --version-sort --reverse | head -1)
echo "[debug] latest addon version: ${LATEST_ADD_VERSION}"

echo "[debug] create or update existing addon"
if aws eks list-addons --cluster-name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" --output "text" | grep -q "${ADDON_NAME}"; then
    EXISTED_ADDON_VERSION=$(aws eks describe-addon --cluster-name "${EKS_CLUSTER_NAME}" --addon-name "${ADDON_NAME}" --region "${AWS_REGION}" --output "json" | jq -r '.addon.addonVersion')
    echo "[debug] existed addon version: ${EXISTED_ADDON_VERSION}"

    aws eks update-addon \
      --cluster-name "${EKS_CLUSTER_NAME}" \
      --region "${AWS_REGION}" \
      --addon-name "${ADDON_NAME}" \
      --addon-version "${LATEST_ADD_VERSION}" \
      --resolve-conflicts "OVERWRITE"
else
    aws eks create-addon \
      --cluster-name "${EKS_CLUSTER_NAME}" \
      --region "${AWS_REGION}" \
      --addon-name "${ADDON_NAME}" \
      --addon-version "${LATEST_ADD_VERSION}" \
      --resolve-conflicts "OVERWRITE"
fi
