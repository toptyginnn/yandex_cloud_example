# ──────────────────────────────────────────────────────────────────────────────
# PostgreSQL Module – Input Variables
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
  description = "Deployment engine: 'k8s' (CloudNativePG) or 'managed' (Yandex MDB)"
  type        = string
  default     = "k8s"

  validation {
    condition     = contains(["k8s", "managed"], var.engine)
    error_message = "engine must be 'k8s' or 'managed'"
  }
}

# ── Common DB settings ──────────────────────────────────────────────────────
variable "pg_database" {
  description = "PostgreSQL database name"
  type        = string
  default     = "app"
}

variable "pg_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "app"
}

variable "pg_password" {
  description = "PostgreSQL password (sourced from Lockbox)"
  type        = string
  sensitive   = true
}

variable "pg_version" {
  description = "PostgreSQL major version tag for the container image"
  type        = string
  default     = "16"
}

# ── k8s mode settings (CloudNativePG) ───────────────────────────────────────
variable "k8s_namespace" {
  description = "Kubernetes namespace for the PostgreSQL cluster"
  type        = string
  default     = "databases"
}

variable "cnpg_operator_chart_version" {
  description = "CloudNativePG operator Helm chart version"
  type        = string
  default     = "0.21.0"
}

variable "cnpg_instances" {
  description = "Number of PostgreSQL instances in CloudNativePG cluster"
  type        = number
  default     = 1
}

variable "pvc_size" {
  description = "PVC size for PostgreSQL data (k8s mode)"
  type        = string
  default     = "10Gi"
}

variable "storage_class" {
  description = "Kubernetes StorageClass name (Yandex CSI)"
  type        = string
  default     = "yc-network-ssd"
}

# ── Managed mode settings ───────────────────────────────────────────────────
variable "network_id" {
  description = "VPC network ID (managed mode)"
  type        = string
  default     = ""
}

variable "mdb_resource_preset" {
  description = "MDB resource preset (e.g. s2.micro)"
  type        = string
  default     = "s2.micro"
}

variable "mdb_disk_size_gb" {
  description = "Disk size in GB for managed PostgreSQL"
  type        = number
  default     = 20
}

variable "mdb_host_zones" {
  description = "List of host zone/subnet pairs for MDB cluster"
  type = list(object({
    zone      = string
    subnet_id = string
  }))
  default = []
}
