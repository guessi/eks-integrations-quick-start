# Quick start scripts for common Amazon EKS integrations

## Prerequisites

- [eksctl](https://eksctl.io/) - The official CLI for Amazon EKS
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - The Kubernetes command-line tool
- [helm](https://helm.sh/) - The Kubernetes Package Manage

## Assumptions

- Your AWS Profile have proper permission configured.

## Supported integrations

| Quick Start Link                                                                  | EKS Managed Addon         | Maintained by AWS         | Maintained by communicity |
|:----------------------------------------------------------------------------------|:--------------------------|:--------------------------|:--------------------------|
| [Amazon EBS CSI Driver](./scripts/aws-ebs-csi-driver)                             | :white_check_mark:        | :white_check_mark:        | :heavy_minus_sign:        |
| [Amazon EFS CSI Driver](./scripts/aws-efs-csi-driver)                             | :white_check_mark:        | :white_check_mark:        | :heavy_minus_sign:        |
| [AWS Load Balancer Controller](./scripts/aws-load-balancer-controller)            | :heavy_minus_sign:        | :white_check_mark:        | :heavy_minus_sign:        |
| [App Mesh Controller](./scripts/appmesh-controller)                               | :heavy_minus_sign:        | :white_check_mark:        | :heavy_minus_sign:        |
| [AWS Gateway API Controller](./scripts/aws-gateway-api-controller)                | :heavy_minus_sign:        | :white_check_mark:        | :heavy_minus_sign:        |
| [Karpenter](./scripts/karpenter)                                                  | :heavy_minus_sign:        | :white_check_mark:        | :heavy_minus_sign:        |
| [Container Insights with Fluent-bit](./scripts/container-insights-with-fluentBit) | :heavy_minus_sign:        | :white_check_mark:        | :heavy_minus_sign:        |
| [Cluster AutoScaler](./scripts/cluster-autoscaler)                                | :heavy_minus_sign:        | :heavy_minus_sign:        | :white_check_mark:        |
| [Metrics Server](./scripts/metrics-server)                                        | :white_check_mark:        | :heavy_minus_sign:        | :white_check_mark:        |
| [kube-state-metrics](./scripts/kube-state-metrics)                                | :heavy_minus_sign:        | :heavy_minus_sign:        | :white_check_mark:        |
| [Cert Manager](./scripts/cert-manager)                                            | :white_check_mark:        | :heavy_minus_sign:        | :white_check_mark:        |
| [Grafana](./scripts/grafana)                                                      | :heavy_minus_sign:        | :heavy_minus_sign:        | :white_check_mark:        |
| [Prometheus](./scripts/prometheus)                                                | :heavy_minus_sign:        | :heavy_minus_sign:        | :white_check_mark:        |
| [Ingress Nginx Controller](./scripts/ingress-nginx-controller)                    | :heavy_minus_sign:        | :heavy_minus_sign:        | :white_check_mark:        |

## License

[GPLv2](LICENSE)

## Author

[guessi](https://github.com/guessi)
