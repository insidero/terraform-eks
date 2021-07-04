module "network" {
  source             = "../modules/network"
  availability_zones = var.availability_zones
  cidr               = var.cidr
}

module "iam" {
  source                      = "../modules/iam"
}
