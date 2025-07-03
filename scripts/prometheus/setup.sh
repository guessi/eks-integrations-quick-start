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

echo "[debug] detecting namespace existance"
kubectl get namespace | grep -q 'prometheus'

if [ $? -ne 0 ]; then
  echo "[debug] creating namespace"
  kubectl create namespace prometheus
else
  echo "[debug] found namespace"
fi

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'prometheus'

echo "[debug] setup prometheus-community/prometheus"
helm upgrade \
  --namespace prometheus \
  --install prometheus \
  prometheus-community/prometheus \
  --values values.yaml \

echo "[debug] listing installed"
helm list --all-namespaces --filter prometheus
