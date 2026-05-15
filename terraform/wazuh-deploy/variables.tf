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

variable "metasploit_workspace_name" {
  description = "Default workspace name prepared on the Metasploit endpoint"
  default     = "customer_pyme_demo"
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
