resource "null_resource" "output" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.root}/output/${var.cluster-name}"
  }
}

# kubeconfig
resource "null_resource" "k8s_kubeconfig" {

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name  ${var.cluster-name}  --region ${var.region}"
    environment = {
      KUBECONFIG = "${path.root}/output/${var.cluster-name}/kubeconfig-${var.cluster-name}"
    }
  }
  depends_on = [
    null_resource.output,
    aws_eks_cluster.default
  ]
}

resource "local_file" "aws_auth" {
  content  = local.config_map_aws_auth
  filename = "${path.root}/output/${var.cluster-name}/aws-auth.yaml"

  depends_on = [
    null_resource.output
  ]
}

resource "null_resource" "aws_auth" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${path.root}/output/${var.cluster-name}/aws-auth.yaml"

    environment = {
      KUBECONFIG = "${path.root}/output/${var.cluster-name}/kubeconfig-${var.cluster-name}"
    }
  }

  depends_on = [
    local_file.aws_auth, aws_eks_cluster.default,
    null_resource.k8s_kubeconfig
  ]
}
