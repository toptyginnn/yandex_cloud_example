# ──────────────────────────────────────────────────────────────────────────────
# Kubernetes Module – Input Variables
# ──────────────────────────────────────────────────────────────────────────────

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "env_name" {
  description = "Environment name (stage, prod)"
  type        = string
}

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

# ── Master configuration ────────────────────────────────────────────────────
variable "master_zones" {
  description = "List of zones for the master (1 = zonal, >1 = regional)"
  type        = list(string)
  default     = ["ru-central1-a"]
}

variable "master_subnet_ids" {
  description = "Map of zone → subnet ID for master placement"
  type        = map(string)
}

variable "master_security_group_ids" {
  description = "Security group IDs for the master"
  type        = list(string)
  default     = []
}

# ── Node group configuration ────────────────────────────────────────────────
variable "node_zones" {
  description = "List of zones for the node group"
  type        = list(string)
  default     = ["ru-central1-a"]
}

variable "node_subnet_ids" {
  description = "Map of zone → subnet ID for node placement"
  type        = map(string)
}

variable "node_security_group_ids" {
  description = "Security group IDs for the nodes"
  type        = list(string)
  default     = []
}

variable "node_cores" {
  description = "Number of CPU cores per node"
  type        = number
  default     = 2
}

variable "node_memory_gb" {
  description = "Memory in GB per node"
  type        = number
  default     = 4
}

variable "node_disk_size_gb" {
  description = "Boot disk size in GB per node"
  type        = number
  default     = 64
}

variable "node_disk_type" {
  description = "Boot disk type per node (network-ssd, network-hdd)"
  type        = string
  default     = "network-ssd"
}

variable "node_core_fraction" {
  description = "Guaranteed vCPU fraction per node (20, 50, or 100)"
  type        = number
  default     = 100
}

variable "node_preemptible" {
  description = "Use preemptible (spot) instances for nodes"
  type        = bool
  default     = false
}

variable "node_auto_scaling" {
  description = "Enable auto-scaling for the node group"
  type        = bool
  default     = false
}

variable "node_fixed_count" {
  description = "Fixed number of nodes (when auto_scaling = false)"
  type        = number
  default     = 2
}

variable "node_auto_scale_min" {
  description = "Minimum nodes in auto-scale mode"
  type        = number
  default     = 2
}

variable "node_auto_scale_max" {
  description = "Maximum nodes in auto-scale mode"
  type        = number
  default     = 5
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for node access"
  type        = list(string)
}

variable "cluster_ipv4_range" {
  description = "CIDR for pod IP addresses (must not overlap with other clusters in the same VPC)"
  type        = string
  default     = "10.112.0.0/16"
}

variable "service_ipv4_range" {
  description = "CIDR for service IP addresses (must not overlap with other clusters in the same VPC)"
  type        = string
  default     = "10.96.0.0/16"
}
