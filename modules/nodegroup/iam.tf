locals {
  aws_policy_prefix = format("arn:%s:iam::aws:policy", join("", data.aws_partition.current.*.partition))
}

data "aws_partition" "current" {
  count = local.enabled ? 1 : 0
}

data "aws_iam_policy_document" "assume_role" {
  count = local.enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "amazon_eks_worker_node_autoscale_policy" {
  count = (local.enabled && var.worker_role_autoscale_iam_enabled) ? 1 : 0
  statement {
    sid = "AllowToScaleEKSNodeGroupAutoScalingGroup"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions"
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "amazon_eks_worker_node_autoscale_policy" {
  count  = (local.enabled && var.worker_role_autoscale_iam_enabled) ? 1 : 0
  name   = "${var.label.id}-autoscale-worker-node-policy"
  policy = join("", data.aws_iam_policy_document.amazon_eks_worker_node_autoscale_policy.*.json)
}

resource "aws_iam_role" "default" {
  count                = local.enabled ? 1 : 0
  name                 = "${var.label.id}-worker-node-role"
  assume_role_policy   = join("", data.aws_iam_policy_document.assume_role.*.json)
  permissions_boundary = var.permissions_boundary
  tags                 = var.label.tags
}

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  count      = local.enabled ? 1 : 0
  policy_arn = format("%s/%s", local.aws_policy_prefix, "AmazonEKSWorkerNodePolicy")
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_autoscale_policy" {
  count      = (local.enabled && var.worker_role_autoscale_iam_enabled) ? 1 : 0
  policy_arn = join("", aws_iam_policy.amazon_eks_worker_node_autoscale_policy.*.arn)
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  count      = local.enabled ? 1 : 0
  policy_arn = format("%s/%s", local.aws_policy_prefix, "AmazonEKS_CNI_Policy")
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  count      = local.enabled ? 1 : 0
  policy_arn = format("%s/%s", local.aws_policy_prefix, "AmazonEC2ContainerRegistryReadOnly")
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "existing_policies_for_eks_workers_role" {
  for_each   = local.enabled ? toset(var.existing_workers_role_policy_arns) : []
  policy_arn = each.value
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role" "cluster_autoscaler_role" {
  count = local.enabled ? 1 : 0

  name = "${var.cluster_name}-cluster-autoscaler-role"

  assume_role_policy = templatefile("${path.module}/policies/oidc_assume_role_policy.json", { OIDC_ARN = var.aws_iam_openid_connect_provider[0].arn, OIDC_URL = replace(var.aws_iam_openid_connect_provider[0].url, "https://", ""), NAMESPACE = "kube-system", SA_NAME = "cluster-autoscaler" })
  depends_on = [var.aws_iam_openid_connect_provider]
}

resource "aws_iam_role_policy" "cluster_autoscaler_policy" {
  count = local.enabled ? 1 : 0

  name = "CustomPolicy"
  role = aws_iam_role.cluster_autoscaler_role[0].id

  policy = templatefile("${path.module}/policies/cluster_autoscaler_policy.json", {})

  depends_on = [
    aws_iam_role.cluster_autoscaler_role
  ]
}