output "vpc" {
  value = aws_vpc.vpc
}

output "public_subnet_id" {
  value = aws_subnet.public_subnets[0].id
}

output "private_subnet_id" {
  value = aws_subnet.private_subnets[0].id
}

output "public_subnets" {
  value = aws_subnet.public_subnets
}

output "private_subnets" {
  value = aws_subnet.private_subnets
}

output "public_rt" {
  value = aws_route_table.public.*.id
}

output "private_rts" {
  value = aws_route_table.private.*.id
}

output "aws_internet_gateway" {
  value = aws_internet_gateway.igw.id
}