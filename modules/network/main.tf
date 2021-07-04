#
# AWS VPC setup
#

data "aws_region" "current" {}

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = terraform.workspace
  }
}

#
# AWS Subnets setup
#
resource "aws_subnet" "public_subnets" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = element(var.availability_zones, count.index)
  cidr_block = cidrsubnet(
    var.cidr,
    ceil(log(length(var.availability_zones) * 2, 2)),
    count.index,
  )
  map_public_ip_on_launch = true

  tags = {
    Name = "${terraform.workspace}-Public-${count.index}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = element(var.availability_zones, count.index)
  cidr_block = cidrsubnet(
    var.cidr,
    ceil(log(length(var.availability_zones) * 2, 2)),
    length(var.availability_zones) + count.index,
  )
  map_public_ip_on_launch = false

  tags = {
    Name = "${terraform.workspace}-Private-${count.index}"
  }
}

#
# AWS IGW setup
#
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${terraform.workspace}-igw"
  }
}

#
# AWS Nat Gateway setyp
# Used for the private subnets
resource "aws_eip" "nat_gw" {
  count         = length(var.availability_zones)
  vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  count         = length(var.availability_zones)
  allocation_id = element(aws_eip.nat_gw.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnets.*.id, count.index)
}

#
# AWS Route Table setup
#

resource "aws_route_table" "public" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${terraform.workspace}-Public-${count.index}"
  }
}

resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat_gw.*.id, count.index)
  }

  tags = {
    Name = "${terraform.workspace}-Private-${count.index}"
  }
}

resource "aws_route_table_association" "private_subnet" {
  count          = length(var.availability_zones)
  subnet_id      = element(aws_subnet.private_subnets.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

resource "aws_route_table_association" "public_subnet" {
  count          = length(var.availability_zones)
  subnet_id      = element(aws_subnet.public_subnets.*.id, count.index)
  route_table_id = element(aws_route_table.public.*.id, count.index)
}


# resource "aws_vpc_endpoint" "s3" {
#   vpc_id       = aws_vpc.vpc.id
#   service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
#   route_table_ids = concat("${aws_route_table.public.*.id}" , "${aws_route_table.private.*.id}")
# }
