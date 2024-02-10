# Common
EKS_CLUSTER_REGION="us-east-1"
EKS_CLUSTER_NAME="eks-demo"

# IAM Policy Names
IAM_POLICY_NAME_AWSLoadBalancerController="AWS_Load_Balancer_Controller_Policy"
IAM_POLICY_NAME_AppMeshController="AppMesh_Controller_Policy"
IAM_POLICY_NAME_ClusterAutoScaler="Cluster_Autoscaler_Policy"
IAM_POLICY_NAME_Karpenter="KarpenterControllerPolicy-${EKS_CLUSTER_NAME}" # defined by CloudFormation stack
IAM_ROLE_NAME_Karpenter="${EKS_CLUSTER_NAME}-karpenter"

# Service Accounts
SERVICE_ACCOUNT_NAME_AmazonEbsCsiDriver="ebs-csi-controller-sa"
SERVICE_ACCOUNT_NAME_AmazonEfsCsiDriver="efs-csi-controller-sa"
SERVICE_ACCOUNT_NAME_AmazonFsxCsiDriver="fsx-csi-controller-sa"
SERVICE_ACCOUNT_NAME_AppMeshController="appmesh-controller"
SERVICE_ACCOUNT_NAME_AwsLoadBalancerController="aws-load-balancer-controller"
SERVICE_ACCOUNT_NAME_ClusterAutoScaler="cluster-autoscaler"
SERVICE_ACCOUNT_NAME_Karpenter="karpenter"
