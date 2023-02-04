#!/usr/bin/env bash

echo "[debug] detecting chart repo existance"
helm repo list | grep -q 'prometheus-community'

if [ $? -ne 0 ]; then
  echo "[debug] setup chart repo"
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
else
  echo "[debug] found chart repo"
fi

echo "[debug] helm repo update"
helm repo update prometheus-community

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'kube-state-metrics'

echo "[debug] setup prometheus-community/kube-state-metrics"
helm upgrade \
  --namespace prometheus \
  --install kube-state-metrics \
  prometheus-community/kube-state-metrics

echo "[debug] listing installed"
helm list --all-namespaces --filter kube-state-metrics
