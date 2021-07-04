locals {
  enabled = var.context.enabled

  cluster_encryption_config = {
    resources        = var.cluster_encryption_config_resources
    provider_key_arn = local.enabled && var.cluster_encryption_config_enabled && var.cluster_encryption_config_kms_key_id == "" ? join("", aws_kms_key.cluster.*.arn) : var.cluster_encryption_config_kms_key_id
  }
}

data "aws_region" "current" {}

data "aws_partition" "current" {
  count = local.enabled ? 1 : 0
}

resource "aws_cloudwatch_log_group" "default" {
  count             = local.enabled && length(var.enabled_cluster_log_types) > 0 ? 1 : 0
  name              = "/aws/eks/${var.label.id}/cluster"
  retention_in_days = var.cluster_log_retention_period
  tags              = var.label.tags
}

resource "aws_kms_key" "cluster" {
  count                   = local.enabled && var.cluster_encryption_config_enabled && var.cluster_encryption_config_kms_key_id == "" ? 1 : 0
  description             = "EKS Cluster ${var.label.id} Encryption Config KMS Key"
  enable_key_rotation     = var.cluster_encryption_config_kms_key_enable_key_rotation
  deletion_window_in_days = var.cluster_encryption_config_kms_key_deletion_window_in_days
  policy                  = var.cluster_encryption_config_kms_key_policy
  tags                    = var.label.tags
}

resource "aws_kms_alias" "cluster" {
  count         = local.enabled && var.cluster_encryption_config_enabled && var.cluster_encryption_config_kms_key_id == "" ? 1 : 0
  name          = format("alias/%v", var.label.id)
  target_key_id = join("", aws_kms_key.cluster.*.key_id)
}

resource "aws_eks_cluster" "default" {
  count                     = local.enabled ? 1 : 0
  name                      = var.cluster-name
  tags                      = var.label.tags
  role_arn                  = join("", var.eks_cluster_role.*.arn)
  version                   = var.kubernetes_version
  enabled_cluster_log_types = var.enabled_cluster_log_types

  dynamic "encryption_config" {
    for_each = var.cluster_encryption_config_enabled ? [local.cluster_encryption_config] : []
    content {
      resources = lookup(encryption_config.value, "resources")
      provider {
        key_arn = lookup(encryption_config.value, "provider_key_arn")
      }
    }
  }

  vpc_config {
    security_group_ids      = [join("", aws_security_group.default.*.id)]
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  depends_on = [
    aws_cloudwatch_log_group.default
  ]
}

# Enabling IAM Roles for Service Accounts in Kubernetes cluster
#
# From official docs:
# The IAM roles for service accounts feature is available on new Amazon EKS Kubernetes version 1.14 clusters,
# and clusters that were updated to versions 1.14 or 1.13 on or after September 3rd, 2019.
#
# https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
# https://medium.com/@marcincuber/amazon-eks-with-oidc-provider-iam-roles-for-kubernetes-services-accounts-59015d15cb0c
#

/* data "tls_certificate" "cluster" {
  count = (local.enabled && var.oidc_provider_enabled) ? 1 : 0
  url = aws_eks_cluster.default[count.index].identity.0.oidc.0.issuer
} */

resource "aws_iam_openid_connect_provider" "default" {
  count = (local.enabled && var.oidc_provider_enabled) ? 1 : 0
  url   = join("", aws_eks_cluster.default.*.identity.0.oidc.0.issuer)

  client_id_list = ["sts.amazonaws.com"]

  # it's thumbprint won't change for many years
  # https://github.com/terraform-providers/terraform-provider-aws/issues/10104
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  /* thumbprint_list = concat([data.tls_certificate.cluster[count.index].certificates.0.sha1_fingerprint], var.oidc_thumbprint_list) */
}

resource "aws_iam_role" "external_secrets" {
  count = local.enabled ? 1 : 0

  name = "${var.cluster-name}-external-secrets"

  assume_role_policy = templatefile("${path.module}/policies/oidc_assume_role_policy.json", { OIDC_ARN = aws_iam_openid_connect_provider.default[0].arn, OIDC_URL = replace(aws_iam_openid_connect_provider.default[0].url, "https://", ""), NAMESPACE = "default", SA_NAME = "external-secrets" })
  depends_on = [aws_iam_openid_connect_provider.default]
}

resource "aws_iam_role_policy" "external_secrets" {
  count = local.enabled ? 1 : 0

  name = "CustomPolicy"
  role = aws_iam_role.external_secrets[0].id

  policy = templatefile("${path.module}/policies/external_secrets_policy.json", {})

  depends_on = [
    aws_iam_role.external_secrets
  ]
}

/* resource "aws_iam_role" "s3_pod_access" {
  count = local.enabled ? 1 : 0

  name = "${var.cluster-name}-s3_pod_access"

  assume_role_policy = templatefile("${path.module}/policies/oidc_assume_role_policy.json", { OIDC_ARN = aws_iam_openid_connect_provider.default[0].arn, OIDC_URL = replace(aws_iam_openid_connect_provider.default[0].url, "https://", ""), NAMESPACE = "core-components", SA_NAME = "s3_pod_access" })
  depends_on = [aws_iam_openid_connect_provider.default]
}

resource "aws_iam_role_policy" "s3_pod_access" {
  count = local.enabled ? 1 : 0

  name = "CustomPolicy"
  role = aws_iam_role.s3_pod_access[0].id

  policy = templatefile("${path.module}/policies/s3_pod_access_policy.json", {ENV = terraform.workspace})

  depends_on = [
    aws_iam_role.s3_pod_access
  ]
} */