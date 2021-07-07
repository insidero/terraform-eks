cidr = "10.4.0.0/16"
availability_zones  = ["us-east-2a","us-east-2b"]
region        = "us-east-2"

kubernetes_version = "1.19"

cluster-name = "cluster"

worker_groups = {
  instance_types    = ["t2.medium"]
  desired_size      = 1
  max_size          = 4
  min_size          = 1
}

enabled_cluster_log_types = ["audit"]
key_name          = "dev-eks"

enable_kubectl               = true
enable_dashboard             = true
# enable_kube2iam              = true
# enable_ambassador            = true

# nginx_ingress = {
#   version   = "0.25.1"
#   acm_cert_arn = ""
# }


# map_additional_iam_users = [{
#     userarn = "arn:aws:iam::924502671932:user/dev-eks",
#     username = "dev-eks",
#     groups = ["system:masters"]}]