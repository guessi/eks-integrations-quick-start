#!/usr/bin/env bash

kubectl delete --ignore-not-found -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml

kubectl delete --ignore-not-found -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
kubectl delete --ignore-not-found -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml

kubectl delete --ignore-not-found -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
kubectl delete --ignore-not-found -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml

kubectl delete --ignore-not-found -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
kubectl delete --ignore-not-found -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/experimental-install.yaml

helm delete --ignore-not-found -n kube-system aws-load-balancer-controller

kubectl delete --ignore-not-found -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
