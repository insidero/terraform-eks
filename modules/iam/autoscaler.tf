resource "aws_iam_role" "eks_autoscaler_role" {
  name = "terraform-${terraform.workspace}-eks-autoscaler-role"
  depends_on = [ aws_iam_role.eks_node_role ]
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_role.eks_node_role.arn}"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "eks_autoscaler_policy" {
  depends_on = [ aws_iam_role.eks_autoscaler_role ]
  name = "terraform-${terraform.workspace}-eks-autoscaler-policy"
  role = aws_iam_role.eks_autoscaler_role.name
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
