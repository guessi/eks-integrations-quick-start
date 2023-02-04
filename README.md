# eks-addons-quick-start

Quick start scripts for installing EKS addons with helm charts.

## Prerequisites

- [eksctl](https://eksctl.io/) - The official CLI for Amazon EKS
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - The Kubernetes command-line tool
- [helm](https://helm.sh/) - The Kubernetes Package Manage

## Assumptions

- Your AWS Profile have proper permission configured.
- All the tools required were setup properly
- All the resources are under `us-east-1`
- The cluster name would be `eks-demo`

## Supported Addons:

- [AWS EBS CSI Driver](./scripts/aws-ebs-csi-driver)
- [AWS EFS CSI Driver](./scripts/aws-efs-csi-driver/)
- [AWS FSx CSI Driver](./scripts/aws-fsx-csi-driver/)
- [AWS Load Balancer Controller](./scripts/aws-load-balancer-controller/)
- [AWS Node Termination Handler](./scripts/aws-node-termination-handler/)
- [App Mesh Controller](./scripts/appmesh-controller/)
- [Cert Manager](./scripts/cert-manager/)
- [Cluster AutoScaler](./scripts/cluster-autoscaler/)
- [Karpenter](./scripts/karpenter/)
- [Metrics Server](./scripts/metrics-server/)
- [kube-state-metrics](./scripts/kube-state-metrics)
- [Prometheus Node Exporter](./scripts/prometheus-node-exporter)
- [Prometheus Pushgateway](./scripts/prometheus-pushgateway)
- [Prometheus Alertmanager](./scripts/alertmanager)
- [Prometheus](./scripts/prometheus)

## License

[GPLv2](LICENSE)

## Author

[guessi](https://github.com/guessi)
