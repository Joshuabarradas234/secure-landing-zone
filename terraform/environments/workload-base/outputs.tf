output "vpc_id" {
  description = "ID of the workload VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = module.networking.nat_gateway_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.networking.internet_gateway_id
}

output "vpc_flow_log_group" {
  description = "CloudWatch Log Group for VPC Flow Logs"
  value       = module.networking.vpc_flow_log_group_name
}

output "deployment_note" {
  description = "Notes on using this template"
  value       = "VPC deployed to ${var.environment} account. Use this as the base layer for ECS/EKS/RDS deployments."
}
