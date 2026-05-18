terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Kubernetes Module – Managed K8s cluster + node group
# ──────────────────────────────────────────────────────────────────────────────

# ── Service Account for the cluster ─────────────────────────────────────────
resource "yandex_iam_service_account" "k8s_cluster" {
  name        = "${var.env_name}-k8s-cluster-sa"
  description = "Service account for K8s cluster in ${var.env_name}"
  folder_id   = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_agent" {
  folder_id = var.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_vpc_public_admin" {
  folder_id = var.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_certificates_downloader" {
  folder_id = var.folder_id
  role      = "load-balancer.admin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

# ── Service Account for node group ──────────────────────────────────────────
resource "yandex_iam_service_account" "k8s_node" {
  name        = "${var.env_name}-k8s-node-sa"
  description = "Service account for K8s nodes in ${var.env_name}"
  folder_id   = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_node_images_puller" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node.id}"
}

# ── KMS Key for secret encryption ───────────────────────────────────────────
resource "yandex_kms_symmetric_key" "k8s" {
  name              = "${var.env_name}-k8s-kms"
  description       = "KMS key for K8s secret encryption"
  folder_id         = var.folder_id
  default_algorithm = "AES_128"
  rotation_period   = "8760h" # 1 year
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_kms" {
  folder_id = var.folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

# ── Managed Kubernetes Cluster ───────────────────────────────────────────────
resource "yandex_kubernetes_cluster" "this" {
  name        = "${var.env_name}-k8s"
  description = "Managed Kubernetes cluster for ${var.env_name}"
  folder_id   = var.folder_id
  network_id  = var.network_id

  master {
    version = var.k8s_version

    dynamic "zonal" {
      for_each = length(var.master_zones) == 1 ? [var.master_zones[0]] : []
      content {
        zone      = zonal.value
        subnet_id = var.master_subnet_ids[zonal.value]
      }
    }

    dynamic "regional" {
      for_each = length(var.master_zones) > 1 ? [true] : []
      content {
        region = "ru-central1"

        dynamic "location" {
          for_each = var.master_zones
          content {
            zone      = location.value
            subnet_id = var.master_subnet_ids[location.value]
          }
        }
      }
    }

    public_ip = false

    security_group_ids = var.master_security_group_ids

    maintenance_policy {
      auto_upgrade = false
    }
  }

  service_account_id      = yandex_iam_service_account.k8s_cluster.id
  node_service_account_id = yandex_iam_service_account.k8s_node.id

  release_channel         = "STABLE"
  network_policy_provider = "CALICO"

  cluster_ipv4_range = var.cluster_ipv4_range
  service_ipv4_range = var.service_ipv4_range

  kms_provider {
    key_id = yandex_kms_symmetric_key.k8s.id
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_cluster_agent,
    yandex_resourcemanager_folder_iam_member.k8s_cluster_vpc_public_admin,
    yandex_resourcemanager_folder_iam_member.k8s_cluster_certificates_downloader,
    yandex_resourcemanager_folder_iam_member.k8s_node_images_puller,
    yandex_resourcemanager_folder_iam_member.k8s_cluster_kms,
  ]
}

# ── Node Group ───────────────────────────────────────────────────────────────
resource "yandex_kubernetes_node_group" "workers" {
  cluster_id  = yandex_kubernetes_cluster.this.id
  name        = "${var.env_name}-workers"
  description = "Worker node group for ${var.env_name}"
  version     = var.k8s_version

  instance_template {
    platform_id = "standard-v3"

    resources {
      cores         = var.node_cores
      memory        = var.node_memory_gb
      core_fraction = var.node_core_fraction
    }

    boot_disk {
      type = var.node_disk_type
      size = var.node_disk_size_gb
    }

    network_interface {
      subnet_ids         = [for z in var.node_zones : var.node_subnet_ids[z]]
      nat                = false
      security_group_ids = var.node_security_group_ids
    }

    scheduling_policy {
      preemptible = var.node_preemptible
    }

    metadata = {
      ssh-keys = join("\n", [for k in var.ssh_public_keys : "ubuntu:${k}"])
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    dynamic "fixed_scale" {
      for_each = var.node_auto_scaling ? [] : [true]
      content {
        size = var.node_fixed_count
      }
    }

    dynamic "auto_scale" {
      for_each = var.node_auto_scaling ? [true] : []
      content {
        min     = var.node_auto_scale_min
        max     = var.node_auto_scale_max
        initial = var.node_auto_scale_min
      }
    }
  }

  allocation_policy {
    dynamic "location" {
      for_each = var.node_zones
      content {
        zone = location.value
      }
    }
  }

  maintenance_policy {
    auto_upgrade = false
    auto_repair  = true
  }

  node_labels = {
    env = var.env_name
  }
}
