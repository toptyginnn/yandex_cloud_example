# ──────────────────────────────────────────────────────────────────────────────
# Vaultwarden Module – Input Variables
# ──────────────────────────────────────────────────────────────────────────────

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "env_name" {
  description = "Environment name (stage, prod)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Vaultwarden"
  type        = string
  default     = "vaultwarden"
}

variable "helm_chart_version" {
  description = "Vaultwarden Helm chart version"
  type        = string
  default     = "0.23.0"
}

variable "domain" {
  description = "Vaultwarden DOMAIN env variable (full URL)"
  type        = string
  default     = "https://vault.internal"
}

variable "ingress_hostname" {
  description = "Hostname for the ingress resource"
  type        = string
  default     = "vault.internal"
}

variable "admin_token" {
  description = "Vaultwarden admin panel token (from Lockbox)"
  type        = string
  sensitive   = true
}

variable "database_url" {
  description = "Database connection URL for Vaultwarden (SQLite path or PostgreSQL URL)"
  type        = string
  default     = "/data/db.sqlite3"
}

variable "pvc_size" {
  description = "PVC size for /data"
  type        = string
  default     = "1Gi"
}

variable "storage_class" {
  description = "Kubernetes StorageClass name"
  type        = string
  default     = "yc-network-ssd"
}
