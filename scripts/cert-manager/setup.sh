#!/usr/bin/env bash

# CHART VERSION	APP VERSION
# ---------------------------
# v1.10.1      	v1.10.1
# v1.10.0      	v1.10.0
# v1.9.1       	v1.9.1

APP_VERSION="1.10.1"
CHART_VERSION="v1.10.1"

echo "[debug] detecting chart repo existance"
helm repo list | grep -q 'cert-manager'

if [ $? -ne 0 ]; then
  echo "[debug] setup chart repo"
  helm repo add jetstack https://charts.jetstack.io || true
else
  echo "[debug] found chart repo"
fi

echo "[debug] helm repo update"
helm repo update jetstack

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'cert-manager'

echo "[debug] setup jetstack/cert-manager"
helm upgrade \
  --namespace cert-manager \
  --install cert-manager \
  jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version ${CHART_VERSION} \
    --set installCRDs=true

echo "[debug] listing installed"
helm list --all-namespaces --filter cert-manager
