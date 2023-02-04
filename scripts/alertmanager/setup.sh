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
helm list --all-namespaces | grep -q 'alertmanager'

echo "[debug] setup prometheus-community/alertmanager"
helm upgrade \
  --namespace prometheus \
  --install alertmanager \
  prometheus-community/alertmanager

echo "[debug] listing installed"
helm list --all-namespaces --filter alertmanager
