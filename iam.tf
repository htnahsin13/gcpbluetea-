# ==============================================================================
# iam.tf
# GCP Blue Team Lab — Service Accounts and IAM Permissions
# ==============================================================================

# ------------------------------------------------------------------------------
# Service Account: Kali Linux Attacker VM
# Minimal permissions — the attacker VM should have no GCP API access.
# ------------------------------------------------------------------------------

resource "google_service_account" "kali_sa" {
  account_id   = "sa-kali-attacker"
  display_name = "Kali Linux Attacker VM Service Account"
  description  = "Minimal service account for the Kali Linux attacker VM. No GCP API permissions granted."
  project      = var.project_id

  depends_on = [google_project_service.iam_api]
}

# ------------------------------------------------------------------------------
# Service Account: Target VMs
# Allows log writing to Cloud Logging for Blue Team visibility.
# ------------------------------------------------------------------------------

resource "google_service_account" "target_vm_sa" {
  account_id   = "sa-target-vm"
  display_name = "Target VM Service Account"
  description  = "Service account for target VMs. Grants log writing for Blue Team monitoring."
  project      = var.project_id

  depends_on = [google_project_service.iam_api]
}

# Grant the target VM service account permission to write logs to Cloud Logging.
resource "google_project_iam_member" "target_vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.target_vm_sa.email}"
}

# Grant the target VM service account permission to write metrics to Cloud Monitoring.
resource "google_project_iam_member" "target_vm_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.target_vm_sa.email}"
}

# ------------------------------------------------------------------------------
# Service Account: Wazuh SIEM Server
# Requires log reading permissions to aggregate logs from other services.
# ------------------------------------------------------------------------------

resource "google_service_account" "siem_sa" {
  account_id   = "sa-wazuh-siem"
  display_name = "Wazuh SIEM Server Service Account"
  description  = "Service account for the Wazuh SIEM server. Grants log reading and writing."
  project      = var.project_id

  depends_on = [google_project_service.iam_api]
}

# Grant the SIEM service account permission to write logs.
resource "google_project_iam_member" "siem_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.siem_sa.email}"
}

# Grant the SIEM service account permission to view logs from across the project.
resource "google_project_iam_member" "siem_log_viewer" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.siem_sa.email}"
}

# Grant the SIEM service account permission to write metrics.
resource "google_project_iam_member" "siem_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.siem_sa.email}"
}

# ------------------------------------------------------------------------------
# IAP Tunnel Access — Grant specified users access to SSH via IAP
# This allows secure SSH access to private VMs without public IPs.
# ------------------------------------------------------------------------------

resource "google_project_iam_member" "iap_tunnel_users" {
  for_each = toset(var.iap_users)

  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = each.value
}

# Grant IAP users the ability to connect to VM instances via OS Login.
resource "google_project_iam_member" "iap_os_login_users" {
  for_each = toset(var.iap_users)

  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = each.value
}
