#!/usr/bin/env bash

echo "[debug] detecting chart repo existance"
helm repo list | grep -q 'grafana'

if [ $? -ne 0 ]; then
  echo "[debug] setup chart repo"
  helm repo add grafana https://grafana.github.io/helm-charts || true
else
  echo "[debug] found chart repo"
fi

echo "[debug] helm repo update"
helm repo update grafana

echo "[debug] detecting namespace existance"
kubectl get namespace | grep -q 'monitoring'

if [ $? -ne 0 ]; then
  echo "[debug] creating namespace"
  kubectl create namespace monitoring
else
  echo "[debug] found namespace"
fi

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'grafana'

echo "[debug] setup grafana/grafana"
helm upgrade \
  --namespace monitoring \
  --install grafana \
  grafana/grafana \
  --values values.yaml

echo "[debug] listing installed"
helm list --all-namespaces --filter grafana
