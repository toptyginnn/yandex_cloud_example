terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# VPN Module – WireGuard on Yandex Compute Instance
# ──────────────────────────────────────────────────────────────────────────────

# ── Static external IP ───────────────────────────────────────────────────────
resource "yandex_vpc_address" "vpn" {
  name      = "${var.env_name}-vpn-ip"
  folder_id = var.folder_id

  external_ipv4_address {
    zone_id = var.zone
  }
}

# ── WireGuard Server Instance ────────────────────────────────────────────────
resource "yandex_compute_instance" "vpn" {
  name        = "${var.env_name}-vpn"
  hostname    = "${var.env_name}-vpn"
  folder_id   = var.folder_id
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = var.ubuntu_image_id
      size     = 30
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = var.subnet_id
    nat                = true
    nat_ip_address     = yandex_vpc_address.vpn.external_ipv4_address[0].address
    security_group_ids = var.security_group_ids
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/cloud-init.yaml", {
      ssh_public_keys = var.ssh_public_keys
    })
  }

  scheduling_policy {
    preemptible = false
  }

  labels = {
    env  = var.env_name
    role = "netbird"
  }
}
