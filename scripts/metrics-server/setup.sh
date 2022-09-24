#!/usr/bin/env bash

echo "[debug] detecting chart repo existance"
helm repo list | grep -q 'metrics-server'

if [ $? -ne 0 ]; then
  echo "[debug] setup chart repo"
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server || true
else
  echo "[debug] found chart repo"
fi

echo "[debug] helm repo update"
helm repo update metrics-server

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'metrics-server'

echo "[debug] setup metrics-server/metrics-server"
helm upgrade \
  --namespace kube-system \
  --install metrics-server \
  metrics-server/metrics-server

echo "[debug] listing installed"
helm list --all-namespaces --filter metrics-server
