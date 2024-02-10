#!/usr/bin/env bash

# CHART VERSION	APP VERSION
# ---------------------------
# 0.23.0       	1.21.0
# 0.22.0       	1.20.0

# ref: https://github.com/aws/aws-node-termination-handler/releases/tag/v1.21.0
# ref: https://github.com/aws/aws-node-termination-handler/tree/v1.21.0/config/helm/aws-node-termination-handler

APP_VERSION="1.20.0" # image for 1.21.0 is not yet published
CHART_VERSION="0.22.0"

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
