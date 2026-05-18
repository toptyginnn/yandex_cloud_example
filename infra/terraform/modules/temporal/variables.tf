# ──────────────────────────────────────────────────────────────────────────────
# Temporal Module – Input Variables
# ──────────────────────────────────────────────────────────────────────────────

variable "env_name" {
  description = "Environment name (stage, prod)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Temporal"
  type        = string
  default     = "temporal"
}

variable "helm_chart_version" {
  description = "Temporal Helm chart version"
  type        = string
  default     = "0.45.0"
}

variable "server_replica_count" {
  description = "Number of Temporal server replicas"
  type        = number
  default     = 1
}

variable "web_enabled" {
  description = "Enable Temporal Web UI"
  type        = bool
  default     = true
}

variable "admintools_enabled" {
  description = "Enable Temporal admin tools"
  type        = bool
  default     = false
}

# ── PostgreSQL mode ──────────────────────────────────────────────────────────
variable "use_embedded_postgresql" {
  description = "Use embedded PostgreSQL (true for stage, false for prod with external)"
  type        = bool
  default     = true
}

variable "external_pg_host" {
  description = "External PostgreSQL host (prod mode)"
  type        = string
  default     = ""
}

variable "external_pg_port" {
  description = "External PostgreSQL port"
  type        = string
  default     = "5432"
}

variable "external_pg_user" {
  description = "External PostgreSQL username"
  type        = string
  default     = "temporal"
}

variable "external_pg_password" {
  description = "External PostgreSQL password (from Lockbox)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "external_pg_database" {
  description = "External PostgreSQL database name for Temporal"
  type        = string
  default     = "temporal"
}
