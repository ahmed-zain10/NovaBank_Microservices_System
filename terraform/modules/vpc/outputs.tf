############################################
# modules/vpc/outputs.tf
############################################

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (tagged kubernetes.io/role/elb for internet-facing ALBs)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (tagged kubernetes.io/role/internal-elb; used by EKS nodes, control plane ENIs, and RDS)"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}
