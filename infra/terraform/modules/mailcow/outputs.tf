# ──────────────────────────────────────────────────────────────────────────────
# Mailcow Module – Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "mailcow_public_ip" {
  description = "Mailcow server static public IP (use for A/MX/PTR DNS records)"
  value       = yandex_vpc_address.mailcow.external_ipv4_address[0].address
}

output "mailcow_internal_ip" {
  description = "Mailcow server internal IP (access via VPN)"
  value       = yandex_compute_instance.mailcow.network_interface[0].ip_address
}

output "mailcow_fqdn" {
  description = "Mailcow instance hostname"
  value       = yandex_compute_instance.mailcow.fqdn
}

output "mailcow_data_disk_id" {
  description = "Mailcow data disk ID"
  value       = yandex_compute_disk.mailcow_data.id
}
