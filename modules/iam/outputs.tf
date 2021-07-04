output "eks_node_role" {
  value = aws_iam_role.eks_node_role
}

output "eks_cluster_role" {
  value = aws_iam_role.eks_cluster_role
}

output "eks_node_profile" {
  value = aws_iam_instance_profile.eks_node_profile
}

output "eks_autoscaler_role" {
  value = aws_iam_role.eks_autoscaler_role
}

# output "user_access_keys" {
#   value = aws_iam_access_key.generic-eks
# }

# output "aws_iam_user" {
#   value = aws_iam_user.generic-eks
# }

# output "aws_iam_group" {
#   value = aws_iam_group.generic-eks
# }
