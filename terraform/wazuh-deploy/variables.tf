variable "project_id" {
  description = "GCP Project ID"
  default     = "wazuh-iac-on-gcp"
}

variable "region" {
  description = "GCP Region"
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  default     = "us-central1-a"
}

variable "environment" {
  description = "Deployment environment label"
  default     = "demo"
}

variable "admin_source_ranges" {
  description = "CIDR ranges allowed to reach SSH and the Wazuh dashboard. Replace 0.0.0.0/0 with your public IP for a safer demo."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "target_source_ranges" {
  description = "CIDR ranges allowed to reach the public demo target and Juice Shop lab."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "extra_agent_source_ranges" {
  description = "Additional CIDR ranges allowed to enroll/send agent traffic to the Wazuh manager. Use this for laptops, external VMs, branch offices, or VPN ranges."
  type        = list(string)
  default     = []
}

variable "enable_gcp_endpoints" {
  description = "Create the monitored lab endpoints in GCP. Set false when endpoints run locally in Docker and only Wazuh remains in GCP."
  type        = bool
  default     = false
}

variable "wazuh_machine_type" {
  description = "Machine type for the Wazuh single-node manager. Use e2-standard-4 or larger for longer demos."
  default     = "e2-medium"
}

variable "target_instance_name" {
  description = "Name of the monitored vulnerable target instance"
  default     = "pyme-demo-target"
}

variable "target_machine_type" {
  description = "Machine type for the monitored vulnerable target"
  default     = "e2-medium"
}

variable "metasploit_instance_name" {
  description = "Name of the monitored Metasploit endpoint"
  default     = "metasploit-node"
}

variable "metasploit_machine_type" {
  description = "Machine type for the monitored Metasploit endpoint"
  default     = "e2-standard-2"
}

variable "metasploit_assign_public_ip" {
  description = "Assign a public IP to the Metasploit endpoint. Set false when the Kali endpoint uses the available public IP quota."
  type        = bool
  default     = true
}

variable "metasploit_workspace_name" {
  description = "Default workspace name prepared on the Metasploit endpoint"
  default     = "customer_pyme_demo"
}

variable "enable_kali_endpoint" {
  description = "Create a monitored Kali attacker endpoint in GCP for controlled lab validation."
  type        = bool
  default     = true
}

variable "kali_instance_name" {
  description = "Name of the monitored Kali attacker endpoint"
  default     = "kali-attacker"
}

variable "kali_machine_type" {
  description = "Machine type for the monitored Kali attacker endpoint"
  default     = "e2-standard-2"
}

variable "kali_boot_disk_size" {
  description = "Boot disk size in GB for the Kali attacker endpoint"
  default     = 40
}

variable "kali_container_image" {
  description = "Kali container image used on the monitored attacker endpoint"
  default     = "kalilinux/kali-rolling"
}

variable "kali_default_scan_target_ip" {
  description = "Default internal lab IP scanned by the Kali endpoint demo script"
  default     = "10.0.1.25"
}

variable "kali_default_http_target_ip" {
  description = "Default internal lab HTTP target IP probed by the Kali endpoint demo script"
  default     = "10.0.1.22"
}

variable "edge_gateway_instance_name" {
  description = "Name of the monitored edge gateway endpoint"
  default     = "edge-gateway"
}

variable "edge_gateway_machine_type" {
  description = "Machine type for the monitored edge gateway endpoint"
  default     = "e2-small"
}

variable "wireguard_port" {
  description = "UDP port exposed by the WireGuard lab gateway"
  default     = 51820
}

variable "db_server_instance_name" {
  description = "Name of the monitored database endpoint"
  default     = "db-server"
}

variable "db_server_machine_type" {
  description = "Machine type for the monitored database endpoint"
  default     = "e2-medium"
}

variable "db_name" {
  description = "Database name created on the monitored database endpoint"
  default     = "customer360"
}

variable "docker_host_instance_name" {
  description = "Name of the monitored docker host endpoint"
  default     = "docker-host"
}

variable "docker_host_machine_type" {
  description = "Machine type for the monitored docker host endpoint"
  default     = "e2-medium"
}

variable "docker_demo_port" {
  description = "External port exposed by the sample service on the monitored docker host"
  default     = 8081
}

variable "linux_ui_instance_name" {
  description = "Name of the monitored Linux desktop endpoint"
  default     = "linux-ui-workstation"
}

variable "linux_ui_machine_type" {
  description = "Machine type for the monitored Linux desktop endpoint"
  default     = "e2-standard-2"
}

variable "linux_ui_boot_disk_size" {
  description = "Boot disk size in GB for the monitored Linux desktop endpoint"
  default     = 50
}

variable "linux_ui_user" {
  description = "Local desktop/RDP user created on the Linux UI endpoint"
  default     = "esquivel"
}

variable "linux_ui_sensitive_dir" {
  description = "Sensitive folder monitored by FIM on the Linux UI endpoint"
  default     = "/home/esquivel/Confidencial"
}

variable "enable_windows_server" {
  description = "Create the Windows Server endpoint. Keep false on GCP Free Trial projects because Windows VMs are blocked there."
  type        = bool
  default     = false
}

variable "windows_instance_name" {
  description = "Name of the monitored Windows Server endpoint"
  default     = "windows-server"
}

variable "windows_machine_type" {
  description = "Machine type for the monitored Windows Server endpoint"
  default     = "e2-standard-2"
}

variable "windows_boot_disk_size" {
  description = "Boot disk size in GB for the monitored Windows Server endpoint"
  default     = 50
}

variable "windows_image" {
  description = "GCP image family used by the monitored Windows Server endpoint"
  default     = "projects/windows-cloud/global/images/family/windows-2022"
}

variable "enable_n8n" {
  description = "Create a persistent n8n automation VM in GCP, connected privately to the Wazuh Indexer."
  type        = bool
  default     = false
}

variable "n8n_instance_name" {
  description = "Name of the n8n automation VM"
  default     = "n8n-automation"
}

variable "n8n_machine_type" {
  description = "Machine type for the n8n automation VM"
  default     = "e2-small"
}

variable "n8n_boot_disk_size" {
  description = "Boot disk size in GB for the n8n automation VM"
  default     = 20
}

variable "n8n_data_disk_size" {
  description = "Persistent data disk size in GB for n8n workflows, credentials, SQLite DB and evidence output"
  default     = 20
}

variable "n8n_image" {
  description = "Container image used by the n8n automation VM"
  default     = "n8nio/n8n:1.94.1"
}

variable "n8n_port" {
  description = "Public TCP port exposed by n8n"
  default     = 5678
}

variable "n8n_source_ranges" {
  description = "CIDR ranges allowed to reach n8n. Replace 0.0.0.0/0 with your public IP for safer internet access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "n8n_basic_auth_user" {
  description = "Basic auth username for the public n8n UI"
  default     = "admin"
}

variable "n8n_basic_auth_password" {
  description = "Optional fixed basic auth password for n8n. Leave empty to generate and persist one on the n8n data disk."
  type        = string
  default     = ""
  sensitive   = true
}

variable "n8n_encryption_key" {
  description = "Optional fixed n8n encryption key. Leave empty to generate and persist one on the n8n data disk."
  type        = string
  default     = ""
  sensitive   = true
}

variable "n8n_wazuh_indexer_username" {
  description = "Wazuh Indexer username used by the n8n vulnerability triage workflow"
  default     = "admin"
}

variable "n8n_wazuh_indexer_password" {
  description = "Wazuh Indexer password used by the n8n vulnerability triage workflow"
  type        = string
  default     = "SecretPassword"
  sensitive   = true
}

variable "n8n_wazuh_indexer_insecure_tls" {
  description = "Allow n8n triage script to connect to the self-signed Wazuh Indexer TLS certificate"
  type        = bool
  default     = true
}

variable "demo_company_name" {
  description = "Business-facing name used in the target landing page and demo artifacts"
  default     = "PYME Demo Mexico"
}

variable "compliance_profile" {
  description = "Compliance frameworks represented by the demo"
  default     = "LFPDPPP, PCI-DSS v4.0, ISO 27001:2022"
}

variable "juice_shop_port" {
  description = "External port exposed by the Juice Shop lab"
  default     = 3000
}

variable "wazuh_version" {
  description = "Pinned Wazuh agent version that matches the deployed manager stack"
  default     = "4.13.0-1"
}
