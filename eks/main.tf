provider "aws" {
  region = var.region
}

module "label" {
  source     = "cloudposse/label/null"
  namespace  = "alidiriye"
  stage      = "${terraform.workspace}"
  version    = "0.24.1"
  attributes = ["cluster"]

  context = module.this.context
}

locals {
  # The usage of the specific kubernetes.io/cluster/* resource tags below are required
  # for EKS and Kubernetes to discover and manage networking resources
  # https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html#base-vpc-networking
  /* tags = merge(module.label.tags, map("kubernetes.io/cluster/${module.label.id}", "shared"))

  # Unfortunately, most_recent (https://github.com/cloudposse/terraform-aws-eks-workers/blob/34a43c25624a6efb3ba5d2770a601d7cb3c0d391/main.tf#L141)
  # variable does not work as expected, if you are not going to use custom ami you should
  # enforce usage of eks_worker_ami_name_filter variable to set the right kubernetes version for EKS workers,
  # otherwise will be used the first version of Kubernetes supported by AWS (v1.11) for EKS workers but
  # EKS control plane will use the version specified by kubernetes_version variable.
  eks_worker_ami_name_filter = "amazon-eks-node-${var.kubernetes_version}*"

  # required tags to make ALB ingress work https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html
  public_subnets_additional_tags = {
    "kubernetes.io/role/elb" : 1
  }
  private_subnets_additional_tags = {
    "kubernetes.io/role/internal-elb" : 1
  }
   */
  vpc                 = data.terraform_remote_state.base_infra.outputs.network.vpc
  public_subnets_ids  = data.terraform_remote_state.base_infra.outputs.network.public_subnets.*.id
  private_subnets_ids = data.terraform_remote_state.base_infra.outputs.network.private_subnets.*.id
  eks_cluster_role    = data.terraform_remote_state.base_infra.outputs.iam.eks_cluster_role
  eks_node_role       = data.terraform_remote_state.base_infra.outputs.iam.eks_node_role
  /* eks_node_profile    = data.terraform_remote_state.base_infra.outputs.iam.eks_node_profile */
  /* autoscaler_role     = data.terraform_remote_state.base_infra.outputs.iam.eks_autoscaler_role */

}

module "eks_cluster" {
  source = "../modules/eks"
  cluster-name                 = module.label.id
  region                       = var.region
  vpc_id                       = local.vpc.id
  subnet_ids                   = concat(local.private_subnets_ids, local.public_subnets_ids)
  kubernetes_version           = var.kubernetes_version
  local_exec_interpreter       = var.local_exec_interpreter
  oidc_provider_enabled        = var.oidc_provider_enabled
  enabled_cluster_log_types    = var.enabled_cluster_log_types
  cluster_log_retention_period = var.cluster_log_retention_period
  endpoint_private_access      = true
  eks_node_role                = local.eks_node_role
  eks_cluster_role             = local.eks_cluster_role
  /* autoscaler_role              = local.autoscaler_role */
  enable_kubectl               = true
  enable_dashboard             = true
  enable_kube2iam              = false
  enable_ambassador            = true
  label                        = module.label
  # nginx_ingress                = var.nginx_ingress
  map_additional_iam_users     = var.map_additional_iam_users

  context = module.this.context
}

# Ensure ordering of resource creation to eliminate the race conditions when applying the Kubernetes Auth ConfigMap.
# Do not create Node Group before the EKS cluster is created and the `aws-auth` Kubernetes ConfigMap is applied.
# Otherwise, EKS will create the ConfigMap first and add the managed node role ARNs to it,
# and the kubernetes provider will throw an error that the ConfigMap already exists (because it can't update the map, only create it).
# If we create the ConfigMap first (to add additional roles/users/accounts), EKS will just update it by adding the managed node role ARNs.
data "null_data_source" "wait_for_cluster_and_kubernetes_configmap" {
  inputs = {
    cluster_name             = module.eks_cluster.eks_cluster_id
    kubernetes_config_map_id = module.eks_cluster.kubernetes_config_map_id
  }
}

module "eks_node_group" {
  source  = "../modules/nodegroup"

  subnet_ids        = local.private_subnets_ids
  cluster_name      = data.null_data_source.wait_for_cluster_and_kubernetes_configmap.outputs["cluster_name"]
  instance_types    = var.worker_groups.instance_types
  desired_size      = var.worker_groups.desired_size
  min_size          = var.worker_groups.min_size
  max_size          = var.worker_groups.max_size
  kubernetes_labels = var.kubernetes_labels
  disk_size         = var.disk_size
  label             = module.label
  ec2_ssh_key       = var.key_name
  aws_iam_openid_connect_provider = module.eks_cluster.aws_iam_openid_connect_provider
  context = module.this.context
}
