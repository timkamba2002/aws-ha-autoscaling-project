output "vpc_id" {
  value = var.create ? aws_vpc.main[0].id : data.aws_vpc.main[0].id
}

output "public_subnet_ids" {
  value = var.create ? [
    aws_subnet.public_a[0].id,
    aws_subnet.public_b[0].id
    ] : [
    data.aws_subnet.public_a[0].id,
    data.aws_subnet.public_b[0].id
  ]
}

output "private_subnet_ids" {
  value = var.create ? [
    aws_subnet.private_a[0].id,
    aws_subnet.private_b[0].id
    ] : [
    data.aws_subnet.private_a[0].id,
    data.aws_subnet.private_b[0].id
  ]
}

output "nat_gateway_id" {
  value = var.create ? aws_nat_gateway.nat_gw[0].id : data.aws_nat_gateway.main[0].id
}
