# ==============================================================================
# firewall.tf
# GCP Blue Team Lab — Firewall Rules
# ==============================================================================
# Security principle: Default-deny. Only explicitly permitted traffic is allowed.
# GCP's implied rules deny all ingress and allow all egress by default.
# ==============================================================================

# ------------------------------------------------------------------------------
# UNTRUSTED VPC — Kali Linux Firewall Rules
# ------------------------------------------------------------------------------

# Allow SSH and HTTPS access to Kali Linux from the admin's IP address.
# This enables direct management and GUI access (e.g., via Guacamole or VNC over HTTPS).
resource "google_compute_firewall" "allow_kali_admin_access" {
  name        = "allow-kali-admin-access"
  network     = google_compute_network.vpc_untrusted.name
  description = "Allow SSH (22) and HTTPS (443) from the admin IP to the Kali Linux machine."
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22", "443"]
  }

  # SECURITY: Restrict this to your specific public IP in production.
  # Set var.admin_source_ip to "YOUR_IP/32" in terraform.tfvars.
  source_ranges = [var.admin_source_ip]
  target_tags   = ["kali-attacker"]
}

# Allow Kali Linux to initiate outbound traffic to the trusted zone targets.
# This simulates attack traffic crossing from the untrusted to the trusted zone.
# NOTE: This rule is intentionally permissive for lab purposes.
# In a real environment, this traffic would be blocked.
resource "google_compute_firewall" "allow_kali_to_trusted_egress" {
  name        = "allow-kali-to-trusted-egress"
  network     = google_compute_network.vpc_untrusted.name
  description = "Allow Kali Linux to send traffic toward the trusted network (for attack simulation)."
  direction   = "EGRESS"
  priority    = 1000

  allow {
    protocol = "all"
  }

  destination_ranges = [var.trusted_subnet_cidr]
  target_tags        = ["kali-attacker"]
}

# ------------------------------------------------------------------------------
# TRUSTED VPC — Internal Firewall Rules
# ------------------------------------------------------------------------------

# Allow all internal traffic within the trusted VPC.
# This is necessary for SIEM agents to communicate with the Wazuh manager,
# and for inter-VM communication between targets.
resource "google_compute_firewall" "allow_trusted_internal" {
  name        = "allow-trusted-internal"
  network     = google_compute_network.vpc_trusted.name
  description = "Allow all traffic between VMs within the trusted VPC."
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "all"
  }

  source_ranges = [var.trusted_subnet_cidr]
}

# Allow SSH access to trusted VMs via Google Identity-Aware Proxy (IAP).
# IAP acts as a secure zero-trust bastion host, eliminating the need for
# public IP addresses on internal VMs.
# Google's IAP IP range: 35.235.240.0/20
resource "google_compute_firewall" "allow_iap_ssh_trusted" {
  name        = "allow-iap-ssh-trusted"
  network     = google_compute_network.vpc_trusted.name
  description = "Allow SSH from Google IAP to all VMs in the trusted zone."
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Google's IAP TCP forwarding IP range — do not change this.
  source_ranges = ["35.235.240.0/20"]
}

# Allow HTTPS access to the Wazuh dashboard from the admin's IP via IAP.
resource "google_compute_firewall" "allow_iap_https_siem" {
  name        = "allow-iap-https-siem"
  network     = google_compute_network.vpc_trusted.name
  description = "Allow HTTPS (443) from Google IAP to the Wazuh SIEM dashboard."
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["443", "5601", "9200"] # Wazuh Dashboard, Kibana, Elasticsearch
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["wazuh-siem"]
}

# Allow traffic from the Kali attacker machine (in the untrusted zone)
# to reach the target VMs (in the trusted zone).
# This simulates an attacker who has gained access to the network perimeter.
resource "google_compute_firewall" "allow_attacker_to_targets" {
  name        = "allow-attacker-to-targets"
  network     = google_compute_network.vpc_trusted.name
  description = "Allow simulated attack traffic from the Kali machine to target VMs."
  direction   = "INGRESS"
  priority    = 1100

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8080", "3389", "445", "21", "23"] # Common attack ports
  }

  allow {
    protocol = "icmp"
  }

  # Allow traffic from the untrusted subnet (Kali's network)
  source_ranges = [var.untrusted_subnet_cidr]
  target_tags   = ["target-vm"]
}

# Deny all other ingress traffic to the trusted zone from the untrusted zone.
# This rule has a lower priority number (higher priority) than the allow rule above,
# ensuring only explicitly permitted attack traffic gets through.
resource "google_compute_firewall" "deny_untrusted_to_trusted_default" {
  name        = "deny-untrusted-to-trusted-default"
  network     = google_compute_network.vpc_trusted.name
  description = "Deny all other ingress traffic from the untrusted zone by default."
  direction   = "INGRESS"
  priority    = 65534

  deny {
    protocol = "all"
  }

  source_ranges = [var.untrusted_subnet_cidr]
}
