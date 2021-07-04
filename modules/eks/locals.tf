locals {

  config_map_aws_auth = <<CONFIGMAPAWSAUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${var.eks_node_role.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH

  eks_admin = <<EKSADMIN
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eks-admin
  namespace: kube-system


---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: eks-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: eks-admin
  namespace: kube-system

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubelet-api-admin
subjects:
- kind: User
  name: kube-apiserver-kubelet-client
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: system:kubelet-api-admin
  apiGroup: rbac.authorization.k8s.io


EKSADMIN

  kube2iam = <<KUBE2IAM
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube2iam
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube2iam
  namespace: kube-system
rules:
  - apiGroups: [""]
    resources: ["namespaces","pods"]
    verbs: ["get","watch","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube2iam
  namespace: kube-system
subjects:
- kind: ServiceAccount
  name: kube2iam
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: kube2iam
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube2iam
  namespace: kube-system
  labels:
    app: kube2iam
spec:
  selector:
    matchLabels:
      name: kube2iam
  template:
    metadata:
      labels:
        name: kube2iam
    spec:
      serviceAccountName: kube2iam
      hostNetwork: true
      containers:
        - image: jtblin/kube2iam:latest
          name: kube2iam
          args:
            - "--auto-discover-base-arn"
            - "--auto-discover-default-role"
            - "--iptables=true"
            - "--host-ip=$(HOST_IP)"
            - "--host-interface=${var.enable_calico ? "cali+" : "eni+"}"
            - "--node=$(NODE_NAME)"
          env:
            - name: HOST_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          ports:
            - containerPort: 8181
              hostPort: 8181
              name: http
          securityContext:
            privileged: true
KUBE2IAM
}
