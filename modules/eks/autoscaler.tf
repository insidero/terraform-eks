data "template_file" "cluster_autoscaler" {
  # depends_on = [ null_resource.kube2iam ]
  template = "${file("${path.module}/templates/cluster-autoscaler.yaml.tpl")}"
  vars = {
    cluster_name        = var.cluster-name
    /* autoscaler_role     = var.autoscaler_role.arn */
    autoscaler_version  = var.autoscaler_version
    region              = data.aws_region.current.name
  }
}

resource "local_file" "cluster_autoscaler" {
  content  = data.template_file.cluster_autoscaler.rendered
  filename = "${path.root}/output/${var.cluster-name}/cluster_autoscaler.yaml"
}

resource "null_resource" "autoscaler" {
  depends_on = [ local_file.cluster_autoscaler ]
  provisioner "local-exec" {
    command = "kubectl apply -f ${path.root}/output/${var.cluster-name}/cluster_autoscaler.yaml"
    
    environment = {
      KUBECONFIG = "${path.root}/output/${var.cluster-name}/kubeconfig-${var.cluster-name}"
    }
  }

  triggers = {
    cluster_autoscaler = data.template_file.cluster_autoscaler.rendered
  }
}
