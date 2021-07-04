terraform {
  required_version = "~> 0.13"
  backend "s3" {
    bucket               = "dev-eks-backend"
    region               = "us-east-2"
    key                  = "backend.tfstate"
    workspace_key_prefix = "eks"
    # dynamodb_table       = "terraform-state"
  }
}
