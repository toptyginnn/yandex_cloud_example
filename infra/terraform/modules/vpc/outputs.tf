# ──────────────────────────────────────────────────────────────────────────────
# VPC Module – Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "network_id" {
  description = "ID of the created VPC network"
  value       = local.network_id
}

output "network_name" {
  description = "Name of the created VPC network"
  value       = local.network_name
}

output "public_subnet_ids" {
  description = "Map of zone → subnet ID for public subnets"
  value       = { for k, v in yandex_vpc_subnet.public : k => v.id }
}

output "private_subnet_ids" {
  description = "Map of zone → subnet ID for private subnets"
  value       = { for k, v in yandex_vpc_subnet.private : k => v.id }
}

output "public_subnet_cidrs" {
  description = "Map of zone → CIDR for public subnets"
  value       = { for k, v in yandex_vpc_subnet.public : k => v.v4_cidr_blocks[0] }
}

output "private_subnet_cidrs" {
  description = "Map of zone → CIDR for private subnets"
  value       = { for k, v in yandex_vpc_subnet.private : k => v.v4_cidr_blocks[0] }
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway"
  value       = yandex_vpc_gateway.nat.id
}

output "route_table_id" {
  description = "ID of the private route table (via NAT)"
  value       = yandex_vpc_route_table.private.id
}

output "sg_allow_internal_id" {
  description = "Security group ID: allow-internal"
  value       = yandex_vpc_security_group.allow_internal.id
}

output "sg_allow_vpn_id" {
  description = "Security group ID: allow-vpn"
  value       = yandex_vpc_security_group.allow_vpn.id
}

output "sg_allow_k8s_api_id" {
  description = "Security group ID: allow-k8s-api"
  value       = yandex_vpc_security_group.allow_k8s_api.id
}

output "sg_allow_ssh_id" {
  description = "Security group ID: allow-ssh"
  value       = yandex_vpc_security_group.allow_ssh.id
}

output "sg_allow_web_id" {
  description = "Security group ID: allow-web"
  value       = yandex_vpc_security_group.allow_web.id
}

output "sg_allow_gitlab_public_id" {
  description = "Security group ID: allow-gitlab-public (80/443/22/2222 from 0.0.0.0/0)"
  value       = yandex_vpc_security_group.allow_gitlab_public.id
}

output "sg_allow_mailcow_public_id" {
  description = "Security group ID: allow-mailcow-public (mail ports from 0.0.0.0/0)"
  value       = yandex_vpc_security_group.allow_mailcow_public.id
}

output "sg_allow_nlb_healthchecks_id" {
  description = "Security group ID: allow YC NLB health checks and NodePort range"
  value       = yandex_vpc_security_group.allow_nlb_healthchecks.id
}
