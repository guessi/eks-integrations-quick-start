#!/usr/bin/env bash

# CHART VERSION	APP VERSION
# ---------------------------
# 0.22.0       	1.20.0
# 0.21.0       	1.19.0
# 0.20.3       	1.18.3

# known issue:
# - https://github.com/aws/aws-node-termination-handler/issues/954

APP_VERSION="1.20.0"
CHART_VERSION="0.22.0"

echo "[debug] log into Public ECR"
aws ecr-public get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin public.ecr.aws

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'aws-node-termination-handler'

echo "[debug] setup eks/aws-node-termination-handler"
helm upgrade \
  --namespace kube-system \
  --install aws-node-termination-handler \
  --version ${CHART_VERSION} \
  oci://public.ecr.aws/aws-ec2/helm/aws-node-termination-handler
    # --set enableSpotInterruptionDraining="true" \
    # --set enableRebalanceMonitoring="true" \
    # --set enableRebalanceDraining="true" \
    # --set enableScheduledEventDraining="true" \
    # --set nodeSelector."eks\.amazonaws\.com/capacityType"=SPOT
    # --set nodeSelector."karpenter\.sh/capacity-type"=spot

echo "[debug] listing installed"
helm list --all-namespaces --filter aws-node-termination-handler
