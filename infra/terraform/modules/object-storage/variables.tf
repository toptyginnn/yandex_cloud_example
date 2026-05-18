# ──────────────────────────────────────────────────────────────────────────────
# Object Storage Module – Input Variables
# ──────────────────────────────────────────────────────────────────────────────

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "env_name" {
  description = "Environment name (stage, prod)"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket for the React SPA"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = false
}

# ── CDN settings ─────────────────────────────────────────────────────────────
variable "cdn_enabled" {
  description = "Enable CDN resource in front of the bucket"
  type        = bool
  default     = false
}

variable "cdn_cname" {
  description = "Primary CNAME for the CDN resource"
  type        = string
  default     = ""
}

variable "cdn_secondary_hostnames" {
  description = "Additional hostnames for the CDN resource"
  type        = list(string)
  default     = []
}

variable "cdn_edge_cache_ttl" {
  description = "Edge cache TTL in seconds"
  type        = number
  default     = 3600
}

variable "cdn_browser_cache_ttl" {
  description = "Browser cache TTL in seconds"
  type        = number
  default     = 600
}

# ── TLS Certificate ─────────────────────────────────────────────────────────
variable "tls_certificate_domain" {
  description = "Domain for the TLS certificate (empty string = skip)"
  type        = string
  default     = ""
}
