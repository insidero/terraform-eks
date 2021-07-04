
provider "aws" {
  version = "~> 2.9.0"
  region  = var.region
}

provider "http" {
  version = "~> 1.1.1"
}

provider "null" {
  version = "~> 2.1.2"
}

provider "local" {
  version = "~> 1.2.2"
}

provider "template" {
  version = "~> 2.1.2"
}

provider "random" {
  version = "2.2"
}
