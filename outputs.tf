# ==============================================================================
# outputs.tf
# GCP Blue Team Lab — Output Values
# ==============================================================================

# ------------------------------------------------------------------------------
# Network Outputs
# ------------------------------------------------------------------------------

output "vpc_untrusted_name" {
  description = "Name of the untrusted (attacker) VPC network."
  value       = google_compute_network.vpc_untrusted.name
}

output "vpc_trusted_name" {
  description = "Name of the trusted (defender/target) VPC network."
  value       = google_compute_network.vpc_trusted.name
}

output "subnet_untrusted_cidr" {
  description = "CIDR range of the untrusted subnet."
  value       = google_compute_subnetwork.subnet_untrusted.ip_cidr_range
}

output "subnet_trusted_cidr" {
  description = "CIDR range of the trusted subnet."
  value       = google_compute_subnetwork.subnet_trusted.ip_cidr_range
}

# ------------------------------------------------------------------------------
# Compute Outputs
# ------------------------------------------------------------------------------

output "kali_attacker_public_ip" {
  description = "Public IP address of the Kali Linux attacker machine. Use this to SSH directly."
  value       = google_compute_instance.kali_attacker.network_interface[0].access_config[0].nat_ip
}

output "kali_attacker_internal_ip" {
  description = "Internal IP address of the Kali Linux attacker machine."
  value       = google_compute_instance.kali_attacker.network_interface[0].network_ip
}

output "target_linux_01_internal_ip" {
  description = "Internal IP address of Target Linux VM 01."
  value       = google_compute_instance.target_linux_01.network_interface[0].network_ip
}

output "target_linux_02_internal_ip" {
  description = "Internal IP address of Target Linux VM 02 (DVWA)."
  value       = google_compute_instance.target_linux_02.network_interface[0].network_ip
}

output "wazuh_siem_internal_ip" {
  description = "Internal IP address of the Wazuh SIEM server."
  value       = google_compute_instance.wazuh_siem.network_interface[0].network_ip
}

# ------------------------------------------------------------------------------
# Connection Instructions
# ------------------------------------------------------------------------------

output "ssh_kali_command" {
  description = "SSH command to connect to the Kali Linux machine."
  value       = "ssh kali@${google_compute_instance.kali_attacker.network_interface[0].access_config[0].nat_ip}"
}

output "iap_ssh_target_01_command" {
  description = "IAP tunnel SSH command to connect to Target Linux VM 01."
  value       = "gcloud compute ssh target-linux-01 --tunnel-through-iap --zone=${var.zone} --project=${var.project_id}"
}

output "iap_ssh_target_02_command" {
  description = "IAP tunnel SSH command to connect to Target Linux VM 02 (DVWA)."
  value       = "gcloud compute ssh target-linux-02 --tunnel-through-iap --zone=${var.zone} --project=${var.project_id}"
}

output "iap_ssh_wazuh_command" {
  description = "IAP tunnel SSH command to connect to the Wazuh SIEM server."
  value       = "gcloud compute ssh wazuh-siem --tunnel-through-iap --zone=${var.zone} --project=${var.project_id}"
}

output "wazuh_dashboard_tunnel_command" {
  description = "Command to create an IAP tunnel to access the Wazuh Dashboard in your local browser at https://localhost:8443"
  value       = "gcloud compute start-iap-tunnel wazuh-siem 443 --local-host-port=localhost:8443 --zone=${var.zone} --project=${var.project_id}"
}
