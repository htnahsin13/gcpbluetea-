# ==============================================================================
# networking.tf
# GCP Blue Team Lab — VPC Networks, Subnets, and Flow Logs
# ==============================================================================

# ------------------------------------------------------------------------------
# UNTRUSTED VPC — Attacker Zone (Kali Linux)
# Simulates the external internet / attacker-controlled network.
# CIDR: 10.10.10.0/24
# ------------------------------------------------------------------------------

resource "google_compute_network" "vpc_untrusted" {
  name                    = "vpc-untrusted"
  auto_create_subnetworks = false
  description             = "Untrusted zone — external attacker network (Kali Linux)."

  depends_on = [google_project_service.compute_api]
}

resource "google_compute_subnetwork" "subnet_untrusted" {
  name          = "subnet-untrusted"
  ip_cidr_range = var.untrusted_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_untrusted.id
  description   = "Subnet for the Kali Linux attacker machine."

  # Flow logs are not strictly necessary on the attacker subnet,
  # but can be enabled for full traffic visibility.
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ------------------------------------------------------------------------------
# TRUSTED VPC — Defender / Target Zone
# Simulates the internal corporate network being defended.
# CIDR: 192.168.10.0/24
# ------------------------------------------------------------------------------

resource "google_compute_network" "vpc_trusted" {
  name                    = "vpc-trusted"
  auto_create_subnetworks = false
  description             = "Trusted zone — internal network with target VMs and SIEM."

  depends_on = [google_project_service.compute_api]
}

resource "google_compute_subnetwork" "subnet_trusted" {
  name          = "subnet-trusted"
  ip_cidr_range = var.trusted_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_trusted.id
  description   = "Subnet for target VMs and the Wazuh SIEM server."

  # VPC Flow Logs are critical for Blue Team network traffic analysis.
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ------------------------------------------------------------------------------
# Cloud NAT — Allows trusted VMs (with no public IP) to reach the internet
# for package installation and updates.
# ------------------------------------------------------------------------------

resource "google_compute_router" "nat_router" {
  name    = "nat-router-trusted"
  region  = var.region
  network = google_compute_network.vpc_trusted.id

  depends_on = [google_compute_network.vpc_trusted]
}

resource "google_compute_router_nat" "cloud_nat" {
  name                               = "cloud-nat-trusted"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
