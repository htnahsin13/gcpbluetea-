# ==============================================================================
# variables.tf
# GCP Blue Team Lab — Input Variables
# ==============================================================================

variable "project_id" {
  description = "The GCP Project ID where all resources will be deployed."
  type        = string
}

variable "region" {
  description = "The GCP region for resource deployment."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for resource deployment."
  type        = string
  default     = "us-central1-a"
}

# ------------------------------------------------------------------------------
# Network Variables
# ------------------------------------------------------------------------------

variable "untrusted_subnet_cidr" {
  description = "CIDR range for the untrusted (attacker) subnet."
  type        = string
  default     = "10.10.10.0/24"
}

variable "trusted_subnet_cidr" {
  description = "CIDR range for the trusted (internal/target) subnet."
  type        = string
  default     = "192.168.10.0/24"
}

# ------------------------------------------------------------------------------
# Access Control Variables
# ------------------------------------------------------------------------------

variable "admin_source_ip" {
  description = "Your public IP address (CIDR notation) for restricting SSH/HTTPS access to the Kali machine. Example: '1.2.3.4/32'."
  type        = string
  # IMPORTANT: Replace this with your actual public IP for security.
  # You can find it by running: curl ifconfig.me
  default     = "0.0.0.0/0"
}

variable "iap_users" {
  description = "List of users or service accounts that are granted IAP tunnel access to VMs in the trusted zone. Format: 'user:email@example.com' or 'serviceAccount:sa@project.iam.gserviceaccount.com'."
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------------------
# Compute Variables
# ------------------------------------------------------------------------------

variable "kali_machine_type" {
  description = "Machine type for the Kali Linux attacker VM."
  type        = string
  default     = "e2-medium"
}

variable "target_machine_type" {
  description = "Machine type for the target/victim VMs."
  type        = string
  default     = "e2-small"
}

variable "siem_machine_type" {
  description = "Machine type for the Wazuh SIEM server. Requires at least 4 vCPUs and 8GB RAM."
  type        = string
  default     = "e2-standard-4"
}

variable "kali_disk_size_gb" {
  description = "Boot disk size in GB for the Kali Linux VM."
  type        = number
  default     = 50
}

variable "target_disk_size_gb" {
  description = "Boot disk size in GB for target VMs."
  type        = number
  default     = 20
}

variable "siem_disk_size_gb" {
  description = "Boot disk size in GB for the Wazuh SIEM server."
  type        = number
  default     = 100
}

variable "ssh_public_key" {
  description = "Your SSH public key to inject into all VMs for access. Format: 'ssh-rsa AAAA...'"
  type        = string
  sensitive   = true
  default     = ""
}
