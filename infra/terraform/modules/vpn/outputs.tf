# ──────────────────────────────────────────────────────────────────────────────
# VPN Module – Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "vpn_public_ip" {
  description = "Static external IP address of the VPN instance"
  value       = yandex_vpc_address.vpn.external_ipv4_address[0].address
}

output "vpn_instance_id" {
  description = "Compute instance ID of the VPN server"
  value       = yandex_compute_instance.vpn.id
}

output "vpn_internal_ip" {
  description = "Internal IP address of the VPN instance"
  value       = yandex_compute_instance.vpn.network_interface[0].ip_address
}
