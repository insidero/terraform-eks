# Dashboard
resource "local_file" "eks_admin" {
  count = var.enable_dashboard ? 1 : 0

  content  = local.eks_admin
  filename = "${path.root}/output/${var.cluster-name}/eks-admin.yaml"

  depends_on = [
    null_resource.output

  ]
}

resource "null_resource" "dashboard" {
  depends_on = [ null_resource.autoscaler ]
  count = var.enable_dashboard ? 1 : 0

  provisioner "local-exec" {
    command = <<COMMAND
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.1.0/aio/deploy/recommended.yaml \
      && kubectl apply -f ${path.root}/output/${var.cluster-name}/eks-admin.yaml \
      && kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}')
    COMMAND

    environment = {
      KUBECONFIG = "${path.root}/output/${var.cluster-name}/kubeconfig-${var.cluster-name}"
    }
  }
}

# kube2iam
# resource "local_file" "kube2iam" {
#   count = var.enable_kube2iam ? 1 : 0

#   content  = local.kube2iam
#   filename = "${path.root}/output/${var.cluster-name}/kube2iam.yaml"

#   depends_on = [
#     null_resource.output
#   ]
# }

# resource "null_resource" "kube2iam" {
#   count = var.enable_kube2iam ? 1 : 0

#   provisioner "local-exec" {
#     command = "kubectl apply -f ${path.root}/output/${var.cluster-name}/kube2iam.yaml"

#     environment = {
#       KUBECONFIG = "${path.root}/output/${var.cluster-name}/kubeconfig-${var.cluster-name}"
#     }

#   }

#   depends_on = [
#     null_resource.aws_auth
#   ]
# }
