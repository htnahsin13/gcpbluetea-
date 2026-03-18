# ==============================================================================
# compute.tf
# GCP Blue Team Lab — Compute Engine Instances
# ==============================================================================
# Instances:
#   1. kali-attacker       — Kali Linux (untrusted zone, public IP)
#   2. target-linux-01     — Debian Linux victim (trusted zone, no public IP)
#   3. target-linux-02     — Debian Linux victim (trusted zone, no public IP)
#   4. wazuh-siem          — Wazuh SIEM server (trusted zone, no public IP)
# ==============================================================================

locals {
  # Common metadata applied to all instances for SSH key injection.
  # If ssh_public_key is provided, it will be added to all VMs.
  ssh_metadata = var.ssh_public_key != "" ? {
    ssh-keys = "kali:${var.ssh_public_key}"
  } : {}
}

# ==============================================================================
# 1. KALI LINUX — Attacker Machine (Untrusted Zone)
# ==============================================================================

resource "google_compute_instance" "kali_attacker" {
  name         = "kali-attacker"
  machine_type = var.kali_machine_type
  zone         = var.zone
  description  = "Kali Linux attacker machine in the untrusted zone."

  tags = ["kali-attacker"]

  labels = {
    role        = "attacker"
    environment = "lab"
    zone        = "untrusted"
  }

  boot_disk {
    initialize_params {
      # Kali Linux is available via the kali-linux project on GCP.
      # Image: kali-linux-2024 (check latest available with: gcloud compute images list --project kali-linux)
      image = "kali-linux/kali-2024-4"
      size  = var.kali_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_untrusted.id
    subnetwork = google_compute_subnetwork.subnet_untrusted.id

    # Assign an ephemeral public IP to the Kali machine for direct access.
    access_config {
      network_tier = "PREMIUM"
    }
  }

  service_account {
    email  = google_service_account.kali_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = merge(local.ssh_metadata, {
    # Enable OS Login for IAM-based SSH key management (optional for Kali).
    enable-oslogin = "FALSE"
  })

  # Startup script: Update Kali and install common tools.
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive

    echo "[*] Updating Kali Linux..."
    apt-get update -y && apt-get upgrade -y

    echo "[*] Installing additional tools..."
    apt-get install -y \
      nmap \
      metasploit-framework \
      burpsuite \
      gobuster \
      hydra \
      john \
      hashcat \
      sqlmap \
      wireshark \
      net-tools \
      curl \
      wget \
      git \
      python3-pip

    echo "[*] Kali Linux setup complete."
  EOT

  # Ensure APIs are enabled before creating instances.
  depends_on = [
    google_project_service.compute_api,
    google_compute_subnetwork.subnet_untrusted,
  ]
}

# ==============================================================================
# 2. TARGET LINUX VM 01 — Victim Machine (Trusted Zone)
# A standard Debian Linux machine simulating a corporate endpoint.
# ==============================================================================

resource "google_compute_instance" "target_linux_01" {
  name         = "target-linux-01"
  machine_type = var.target_machine_type
  zone         = var.zone
  description  = "Target Linux VM 01 — simulates a corporate endpoint in the trusted zone."

  tags = ["target-vm"]

  labels = {
    role        = "target"
    environment = "lab"
    zone        = "trusted"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.target_disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_trusted.id
    subnetwork = google_compute_subnetwork.subnet_trusted.id
    # No access_config block = no public IP address.
  }

  service_account {
    email  = google_service_account.target_vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  # Startup script: Install Wazuh agent and connect to the SIEM server.
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive

    echo "[*] Updating system..."
    apt-get update -y

    echo "[*] Installing common services to simulate attack surface..."
    apt-get install -y \
      apache2 \
      openssh-server \
      curl \
      wget \
      net-tools \
      python3

    echo "[*] Installing Wazuh Agent..."
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
      | tee /etc/apt/sources.list.d/wazuh.list
    apt-get update -y

    # Wait for Wazuh SIEM to be ready before connecting.
    # The SIEM's internal IP is referenced via its hostname on the trusted subnet.
    WAZUH_MANAGER="${google_compute_instance.wazuh_siem.network_interface[0].network_ip}" \
    apt-get install -y wazuh-agent

    sed -i "s|MANAGER_IP|${google_compute_instance.wazuh_siem.network_interface[0].network_ip}|g" \
      /var/ossec/etc/ossec.conf

    systemctl daemon-reload
    systemctl enable wazuh-agent
    systemctl start wazuh-agent

    echo "[*] Target Linux 01 setup complete."
  EOT

  depends_on = [
    google_project_service.compute_api,
    google_compute_subnetwork.subnet_trusted,
    google_compute_instance.wazuh_siem,
  ]
}

# ==============================================================================
# 3. TARGET LINUX VM 02 — Victim Machine (Trusted Zone)
# A second target to simulate a multi-host network environment.
# ==============================================================================

resource "google_compute_instance" "target_linux_02" {
  name         = "target-linux-02"
  machine_type = var.target_machine_type
  zone         = var.zone
  description  = "Target Linux VM 02 — simulates a second corporate endpoint in the trusted zone."

  tags = ["target-vm"]

  labels = {
    role        = "target"
    environment = "lab"
    zone        = "trusted"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.target_disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_trusted.id
    subnetwork = google_compute_subnetwork.subnet_trusted.id
    # No access_config block = no public IP address.
  }

  service_account {
    email  = google_service_account.target_vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  # Startup script: Install a vulnerable web app (DVWA) for practice.
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive

    echo "[*] Updating system..."
    apt-get update -y

    echo "[*] Installing LAMP stack for DVWA..."
    apt-get install -y \
      apache2 \
      mariadb-server \
      php \
      php-mysqli \
      php-gd \
      libapache2-mod-php \
      curl \
      wget \
      git \
      net-tools

    echo "[*] Deploying DVWA (Damn Vulnerable Web Application)..."
    cd /var/www/html
    git clone https://github.com/digininja/DVWA.git dvwa
    cp dvwa/config/config.inc.php.dist dvwa/config/config.inc.php
    chown -R www-data:www-data dvwa/
    chmod -R 755 dvwa/

    # Configure MariaDB for DVWA
    mysql -e "CREATE DATABASE dvwa;"
    mysql -e "CREATE USER 'dvwa'@'localhost' IDENTIFIED BY 'p@ssw0rd';"
    mysql -e "GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    systemctl restart apache2

    echo "[*] Installing Wazuh Agent..."
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
      | tee /etc/apt/sources.list.d/wazuh.list
    apt-get update -y

    WAZUH_MANAGER="${google_compute_instance.wazuh_siem.network_interface[0].network_ip}" \
    apt-get install -y wazuh-agent

    sed -i "s|MANAGER_IP|${google_compute_instance.wazuh_siem.network_interface[0].network_ip}|g" \
      /var/ossec/etc/ossec.conf

    systemctl daemon-reload
    systemctl enable wazuh-agent
    systemctl start wazuh-agent

    echo "[*] Target Linux 02 (DVWA) setup complete."
  EOT

  depends_on = [
    google_project_service.compute_api,
    google_compute_subnetwork.subnet_trusted,
    google_compute_instance.wazuh_siem,
  ]
}

# ==============================================================================
# 4. WAZUH SIEM SERVER — Defensive Infrastructure (Trusted Zone)
# Centralized SIEM, IDS, and log aggregation platform.
# Wazuh provides: HIDS, FIM, vulnerability detection, compliance.
# ==============================================================================

resource "google_compute_instance" "wazuh_siem" {
  name         = "wazuh-siem"
  machine_type = var.siem_machine_type
  zone         = var.zone
  description  = "Wazuh SIEM server — centralized security monitoring for the trusted zone."

  tags = ["wazuh-siem"]

  labels = {
    role        = "siem"
    environment = "lab"
    zone        = "trusted"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.siem_disk_size_gb
      type  = "pd-ssd" # SSD for better Elasticsearch/Wazuh indexer performance.
    }
  }

  network_interface {
    network    = google_compute_network.vpc_trusted.id
    subnetwork = google_compute_subnetwork.subnet_trusted.id
    # No access_config block = no public IP address.
    # Access via IAP tunnel only.
  }

  service_account {
    email  = google_service_account.siem_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  # Startup script: Automated Wazuh all-in-one installation.
  # This installs the Wazuh Manager, Wazuh Indexer (Elasticsearch), and Wazuh Dashboard.
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive

    echo "[*] Updating Ubuntu..."
    apt-get update -y && apt-get upgrade -y

    echo "[*] Installing prerequisites..."
    apt-get install -y curl wget apt-transport-https gnupg2 lsb-release

    echo "[*] Downloading Wazuh installation assistant..."
    curl -sO https://packages.wazuh.com/4.7/wazuh-install.sh
    curl -sO https://packages.wazuh.com/4.7/config.yml

    # Configure Wazuh for single-node deployment.
    # Replace the default node name and IP with the actual internal IP.
    INTERNAL_IP=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" \
      -H "Metadata-Flavor: Google")

    cat > config.yml <<WAZUH_CONFIG
    nodes:
      indexer:
        - name: node-1
          ip: "$INTERNAL_IP"
      server:
        - name: wazuh-1
          ip: "$INTERNAL_IP"
      dashboard:
        - name: dashboard
          ip: "$INTERNAL_IP"
    WAZUH_CONFIG

    echo "[*] Running Wazuh installation (this may take 10-15 minutes)..."
    bash wazuh-install.sh -a -i

    echo "[*] Wazuh SIEM installation complete."
    echo "[*] Access the Wazuh Dashboard at: https://$INTERNAL_IP"
    echo "[*] Use IAP tunnel to forward port 443 to your local machine."
    echo "[*] Default credentials: admin / (check wazuh-passwords.txt)"

    # Save credentials to a file for retrieval.
    tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt \
      > /root/wazuh-passwords.txt 2>/dev/null || true
  EOT

  depends_on = [
    google_project_service.compute_api,
    google_compute_subnetwork.subnet_trusted,
  ]
}
