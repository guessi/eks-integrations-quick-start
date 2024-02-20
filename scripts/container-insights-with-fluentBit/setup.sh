#!/usr/bin/env bash

source $(pwd)/../config.sh

ClusterName="${EKS_CLUSTER_NAME}"
RegionName="${EKS_CLUSTER_REGION}"
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml

[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'

[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'

kubectl create configmap fluent-bit-cluster-info \
  --from-literal=cluster.name=${ClusterName} \
  --from-literal=http.server=${FluentBitHttpServer} \
  --from-literal=http.port=${FluentBitHttpPort} \
  --from-literal=read.head=${FluentBitReadFromHead} \
  --from-literal=read.tail=${FluentBitReadFromTail} \
  --from-literal=logs.region=${RegionName} -n amazon-cloudwatch \
  -o yaml --dry-run=client | kubectl apply -f -

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml

kubectl get pods -n amazon-cloudwatch
