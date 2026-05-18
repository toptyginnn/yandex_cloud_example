# ──────────────────────────────────────────────────────────────────────────────
# Redis Module – Input Variables
# ──────────────────────────────────────────────────────────────────────────────

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "env_name" {
  description = "Environment name (stage, prod)"
  type        = string
}

variable "engine" {
  description = "Deployment engine: 'k8s' (raw Deployment) or 'managed' (Yandex MDB)"
  type        = string
  default     = "k8s"

  validation {
    condition     = contains(["k8s", "managed"], var.engine)
    error_message = "engine must be 'k8s' or 'managed'"
  }
}

variable "redis_password" {
  description = "Redis password (sourced from Lockbox)"
  type        = string
  sensitive   = true
}

variable "redis_version" {
  description = "Redis Docker image tag (k8s mode)"
  type        = string
  default     = "7-alpine"
}

# ── k8s mode settings ───────────────────────────────────────────────────────
variable "k8s_namespace" {
  description = "Kubernetes namespace for Redis deployment"
  type        = string
  default     = "databases"
}

# ── Managed mode settings ───────────────────────────────────────────────────
variable "network_id" {
  description = "VPC network ID (managed mode)"
  type        = string
  default     = ""
}

variable "mdb_resource_preset" {
  description = "MDB resource preset (e.g. hm3-c2-m8)"
  type        = string
  default     = "hm3-c2-m8"
}

variable "mdb_disk_size_gb" {
  description = "Disk size in GB for managed Redis"
  type        = number
  default     = 16
}

variable "mdb_host_zones" {
  description = "List of host zone/subnet pairs for MDB cluster"
  type = list(object({
    zone      = string
    subnet_id = string
  }))
  default = []
}
