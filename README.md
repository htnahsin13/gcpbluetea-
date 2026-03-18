# GCP Blue Team Cybersecurity Lab

A production-ready Terraform project for deploying a complete Blue Team cybersecurity lab on Google Cloud Platform (GCP). The lab provides a realistic attack-defense environment with an isolated Kali Linux attacker machine, vulnerable target VMs, and a centralized Wazuh SIEM for security monitoring.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GOOGLE CLOUD PLATFORM                        │
│                                                                       │
│  ┌──────────────────────────────┐  ┌───────────────────────────────┐ │
│  │   vpc-untrusted (Attacker)   │  │    vpc-trusted (Defender)     │ │
│  │   CIDR: 10.10.10.0/24        │  │    CIDR: 192.168.10.0/24      │ │
│  │                              │  │                               │ │
│  │  ┌────────────────────────┐  │  │  ┌─────────────────────────┐ │ │
│  │  │   kali-attacker        │  │  │  │   wazuh-siem            │ │ │
│  │  │   Kali Linux           │  │  │  │   Ubuntu + Wazuh        │ │ │
│  │  │   e2-medium            │  │  │  │   e2-standard-4         │ │ │
│  │  │   [PUBLIC IP]          │  │  │  │   [NO PUBLIC IP]        │ │ │
│  │  │   10.10.10.x           │  │  │  │   192.168.10.x          │ │ │
│  │  └────────────────────────┘  │  │  └─────────────────────────┘ │ │
│  │                              │  │                               │ │
│  │  Firewall:                   │  │  ┌─────────────────────────┐ │ │
│  │  - SSH/HTTPS from admin IP   │  │  │   target-linux-01       │ │ │
│  │  - Egress to trusted zone    │  │  │   Debian + Apache       │ │ │
│  │                              │  │  │   e2-small              │ │ │
│  └──────────────────────────────┘  │  │   [NO PUBLIC IP]        │ │ │
│                                    │  │   192.168.10.x          │ │ │
│  ┌──────────────────────────────┐  │  └─────────────────────────┘ │ │
│  │   Internet / Admin           │  │                               │ │
│  │                              │  │  ┌─────────────────────────┐ │ │
│  │   SSH → Kali (Public IP)     │  │  │   target-linux-02       │ │ │
│  │   IAP → Private VMs          │  │  │   Debian + DVWA         │ │ │
│  │                              │  │  │   e2-small              │ │ │
│  └──────────────────────────────┘  │  │   [NO PUBLIC IP]        │ │ │
│                                    │  │   192.168.10.x          │ │ │
│                                    │  └─────────────────────────┘ │ │
│                                    │                               │ │
│                                    │  Firewall:                    │ │
│                                    │  - IAP SSH (35.235.240.0/20) │ │
│                                    │  - Internal traffic allowed   │ │
│                                    │  - Attack traffic from Kali   │ │
│                                    │  - Cloud NAT for outbound     │ │
│                                    └───────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Lab Components

| VM Name | Role | OS | Machine Type | IP Zone | Public IP |
|---|---|---|---|---|---|
| `kali-attacker` | Red Team / Attacker | Kali Linux | e2-medium | Untrusted | Yes |
| `target-linux-01` | Victim Endpoint | Debian 12 + Apache | e2-small | Trusted | No |
| `target-linux-02` | Victim Web App (DVWA) | Debian 12 + DVWA | e2-small | Trusted | No |
| `wazuh-siem` | SIEM / IDS | Ubuntu 22.04 + Wazuh | e2-standard-4 | Trusted | No |

## Prerequisites

Before deploying, ensure you have the following:

1. **GCP Account** with billing enabled and a project created.
2. **Terraform** >= 1.5.0 installed locally, or use Google Cloud Shell (pre-installed).
3. **Google Cloud SDK (`gcloud`)** installed and authenticated:
   ```bash
   gcloud auth application-default login
   gcloud config set project YOUR_PROJECT_ID
   ```
4. **SSH Key Pair** for VM access:
   ```bash
   ssh-keygen -t ed25519 -C "blue-team-lab" -f ~/.ssh/blue_team_lab
   ```

## Deployment Steps

### Step 1: Clone or Download the Project

```bash
git clone <your-repo-url>
cd gcp-blue-team-lab
```

### Step 2: Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in your values:

```hcl
project_id      = "your-gcp-project-id"
region          = "us-central1"
zone            = "us-central1-a"
admin_source_ip = "YOUR_PUBLIC_IP/32"  # Run: curl ifconfig.me
ssh_public_key  = "ssh-ed25519 AAAA..."
iap_users       = ["user:your_email@example.com"]
```

### Step 3: Initialize Terraform

```bash
terraform init
```

### Step 4: Review the Plan

```bash
terraform plan
```

Review the output carefully. You should see resources being created for 2 VPCs, 4 VMs, firewall rules, IAM bindings, and Cloud NAT.

### Step 5: Deploy the Lab

```bash
terraform apply
```

Type `yes` when prompted. The deployment takes approximately **15-20 minutes** due to the Wazuh SIEM installation startup script.

### Step 6: Retrieve Connection Information

After deployment, Terraform will display the output values:

```bash
terraform output
```

---

## Accessing the Lab

### Kali Linux (Direct SSH)

```bash
ssh kali@<kali_attacker_public_ip>
# Or use the output command:
$(terraform output -raw ssh_kali_command)
```

### Target VMs (via IAP Tunnel)

```bash
# Target VM 01
gcloud compute ssh target-linux-01 --tunnel-through-iap --zone=us-central1-a --project=YOUR_PROJECT_ID

# Target VM 02 (DVWA)
gcloud compute ssh target-linux-02 --tunnel-through-iap --zone=us-central1-a --project=YOUR_PROJECT_ID
```

### Wazuh SIEM Dashboard (via IAP Port Forwarding)

```bash
# Step 1: Create an IAP tunnel to forward port 443 locally
gcloud compute start-iap-tunnel wazuh-siem 443 --local-host-port=localhost:8443 \
  --zone=us-central1-a --project=YOUR_PROJECT_ID

# Step 2: Open your browser and navigate to:
# https://localhost:8443

# Step 3: Retrieve Wazuh credentials
gcloud compute ssh wazuh-siem --tunnel-through-iap --zone=us-central1-a \
  --project=YOUR_PROJECT_ID -- "sudo cat /root/wazuh-passwords.txt"
```

---

## Blue Team Practice Scenarios

Once the lab is deployed, you can practice the following scenarios:

### Scenario 1: Network Reconnaissance Detection
1. From Kali, run an Nmap scan against the target VMs.
2. In Wazuh, check the **Security Events** dashboard for port scan alerts.
3. Review VPC Flow Logs in Cloud Logging for the traffic pattern.

### Scenario 2: Brute Force Detection
1. From Kali, use Hydra to brute-force SSH on `target-linux-01`.
2. In Wazuh, observe the `authentication_failed` alerts.
3. Practice writing a custom Wazuh rule to alert on this behavior.

### Scenario 3: Web Application Attack (DVWA)
1. From Kali, use Burp Suite or SQLMap against the DVWA on `target-linux-02`.
2. Monitor Apache access logs forwarded to Wazuh.
3. Practice identifying SQL injection attempts in the SIEM.

### Scenario 4: Incident Response
1. Simulate a compromise on a target VM.
2. Use Wazuh's File Integrity Monitoring (FIM) to detect file changes.
3. Practice containment by modifying firewall rules via Terraform.

---

## Cost Estimation

> **Warning:** Running this lab 24/7 will incur GCP charges. Always run `terraform destroy` when not in use.

| Resource | Machine Type | Estimated Monthly Cost (USD) |
|---|---|---|
| kali-attacker | e2-medium | ~$27 |
| target-linux-01 | e2-small | ~$13 |
| target-linux-02 | e2-small | ~$13 |
| wazuh-siem | e2-standard-4 | ~$97 |
| Persistent Disks | ~190GB total | ~$19 |
| Cloud NAT | Per GB processed | ~$1-5 |
| **Total (approx.)** | | **~$170/month** |

**Cost-saving tips:**
- Use `terraform destroy` after each lab session.
- Use preemptible/spot VMs for non-SIEM instances.
- Reduce machine types if performance allows.

---

## Teardown

To destroy all resources and stop billing:

```bash
terraform destroy
```

Type `yes` when prompted. This will remove all VMs, VPCs, firewall rules, and IAM bindings created by Terraform.

---

## File Structure

```
gcp-blue-team-lab/
├── main.tf                    # Provider config and API enablement
├── variables.tf               # Input variable definitions
├── networking.tf              # VPCs, subnets, Cloud NAT, VPC Flow Logs
├── firewall.tf                # All firewall rules
├── iam.tf                     # Service accounts and IAM bindings
├── compute.tf                 # All VM instances with startup scripts
├── outputs.tf                 # Output values and connection commands
├── terraform.tfvars.example   # Example variable values (copy to .tfvars)
├── .gitignore                 # Excludes sensitive files from version control
└── README.md                  # This file
```
