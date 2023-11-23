#!/usr/bin/env bash

echo "[debug] detecting chart repo existance"
helm repo list | grep -q 'ingress-nginx'

if [ $? -ne 0 ]; then
  echo "[debug] setup chart repo"
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
else
  echo "[debug] found chart repo"
fi

echo "[debug] helm repo update"
helm repo update ingress-nginx

echo "[debug] detecting namespace existance"
kubectl get namespace | grep -q 'ingress-nginx'

if [ $? -ne 0 ]; then
  echo "[debug] creating namespace"
  kubectl create namespace ingress-nginx
else
  echo "[debug] found namespace"
fi

echo "[debug] detecting Helm resource existance"
helm list --all-namespaces | grep -q 'ingress-nginx'

echo "[debug] setup ingress-nginx/ingress-nginx"
helm upgrade \
  --namespace ingress-nginx \
  --install ingress-nginx \
  ingress-nginx/ingress-nginx \
    --values values.yaml \
    --wait

echo "[debug] listing installed"
helm list --filter ingress-nginx --namespace ingress-nginx
