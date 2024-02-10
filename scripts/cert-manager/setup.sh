#!/usr/bin/env bash

# CHART VERSION	APP VERSION
# ---------------------------
# v1.14.2      	v1.14.2
# v1.13.3      	v1.13.3

APP_VERSION="1.14.2"
CHART_VERSION="v1.14.2"

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

echo "[debug] detecting namespace existance"
kubectl get namespace | grep -q 'cert-manager'

if [ $? -ne 0 ]; then
  echo "[debug] creating namespace"
  kubectl create namespace cert-manager
else
  echo "[debug] found namespace"
fi

# echo "[debug] creating Custom Resource Definition (CRDs)"
# kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.2/cert-manager.crds.yaml

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
