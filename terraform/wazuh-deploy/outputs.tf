output "wazuh_dashboard_url" {
  description = "Public URL of the Wazuh dashboard"
  value       = "https://${google_compute_address.wazuh_server_public_ip.address}"
}

output "wazuh_manager_public_ip" {
  description = "Public IP that externally enrolled agents can use when allowed by extra_agent_source_ranges"
  value       = google_compute_address.wazuh_server_public_ip.address
}

output "wazuh_manager_private_ip" {
  description = "Private IP used by monitored agents to reach the Wazuh manager"
  value       = google_compute_instance.wazuh_server.network_interface[0].network_ip
}

output "agent_enrollment_ports" {
  description = "Ports used by Wazuh agents to register and send telemetry"
  value = {
    registration = 1515
    events       = 1514
    cluster      = 1516
    api          = 55000
  }
}

output "n8n_public_ip" {
  description = "Static public IP of the persistent n8n automation VM"
  value       = var.enable_n8n ? google_compute_address.n8n_public_ip[0].address : null
}

output "n8n_url" {
  description = "Public URL of the persistent n8n automation UI"
  value       = var.enable_n8n ? "http://${google_compute_address.n8n_public_ip[0].address}:${var.n8n_port}" : null
}

output "n8n_agent_name" {
  description = "Agent name expected in the Wazuh dashboard for the n8n automation VM"
  value       = var.n8n_instance_name
}

output "n8n_basic_auth_user" {
  description = "Basic-auth username for the public n8n UI"
  value       = var.enable_n8n ? var.n8n_basic_auth_user : null
}

output "n8n_credentials_command" {
  description = "Command to read the generated n8n basic-auth password from the persistent data disk"
  value       = var.enable_n8n ? "gcloud compute ssh ${var.n8n_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo cat /mnt/disks/n8n-data/credentials/n8n-basic-auth-password.txt\"" : null
}

output "n8n_run_triage_command" {
  description = "Command to run the Wazuh vulnerability triage script inside the cloud n8n container"
  value       = var.enable_n8n ? "gcloud compute ssh ${var.n8n_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo docker exec wazuh-security-n8n node /home/node/.n8n/scripts/wazuh-vulnerability-triage.js\"" : null
}

output "n8n_logs_command" {
  description = "Command to inspect the n8n container logs on the cloud VM"
  value       = var.enable_n8n ? "gcloud compute ssh ${var.n8n_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo docker logs --tail 120 wazuh-security-n8n\"" : null
}

output "local_docker_linux_up_command" {
  description = "Command to start all local Linux Docker endpoints against the cloud Wazuh manager"
  value       = ".\\scripts\\local-docker-lab.ps1 -Scope Linux -Action up"
}

output "local_docker_windows_up_command" {
  description = "Command to start the local Windows Docker endpoint after switching Docker Desktop to Windows containers"
  value       = ".\\scripts\\local-docker-lab.ps1 -Scope Windows -Action up"
}

output "target_public_ip" {
  description = "Public IP of the monitored vulnerable target"
  value       = var.enable_gcp_endpoints ? google_compute_instance.ubuntu_endpoint[0].network_interface[0].access_config[0].nat_ip : null
}

output "target_landing_page_url" {
  description = "Public URL of the Juice Shop lab served through Apache"
  value       = var.enable_gcp_endpoints ? "http://${google_compute_instance.ubuntu_endpoint[0].network_interface[0].access_config[0].nat_ip}" : "http://127.0.0.1:8080"
}

output "attack_panel_url" {
  description = "Web panel with buttons that launch controlled Juice Shop demo probes"
  value       = var.enable_gcp_endpoints ? "http://${google_compute_instance.ubuntu_endpoint[0].network_interface[0].access_config[0].nat_ip}/panel/" : "http://127.0.0.1:8080/panel/"
}

output "juice_shop_url" {
  description = "Direct container port of the Juice Shop lab"
  value       = var.enable_gcp_endpoints ? "http://${google_compute_instance.ubuntu_endpoint[0].network_interface[0].access_config[0].nat_ip}:${var.juice_shop_port}" : "http://127.0.0.1:${var.juice_shop_port}"
}

output "metasploit_public_ip" {
  description = "Public IP of the monitored Metasploit endpoint"
  value       = var.enable_gcp_endpoints ? google_compute_instance.metasploit_endpoint[0].network_interface[0].access_config[0].nat_ip : null
}

output "metasploit_agent_name" {
  description = "Agent name expected in the Wazuh dashboard for the Metasploit endpoint"
  value       = var.metasploit_instance_name
}

output "metasploit_console_command" {
  description = "SSH command to open the Metasploit wrapper console on the monitored endpoint"
  value       = var.enable_gcp_endpoints ? "gcloud compute ssh ${var.metasploit_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo /usr/local/bin/msf-lab-console\"" : "docker compose -f docker-compose.endpoints.yml exec ${var.metasploit_instance_name} /usr/local/bin/msf-lab-console"
}

output "metasploit_demo_event_command" {
  description = "Command to generate controlled Metasploit endpoint telemetry"
  value       = var.enable_gcp_endpoints ? "gcloud compute ssh ${var.metasploit_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo /usr/local/bin/metasploit-demo-generate-events.sh\"" : "docker compose -f docker-compose.endpoints.yml exec ${var.metasploit_instance_name} /usr/local/bin/metasploit-demo-generate-events.sh"
}

output "edge_gateway_public_ip" {
  description = "Public IP of the monitored edge gateway endpoint"
  value       = var.enable_gcp_endpoints ? google_compute_instance.edge_gateway[0].network_interface[0].access_config[0].nat_ip : null
}

output "edge_gateway_agent_name" {
  description = "Agent name expected in the Wazuh dashboard for the edge gateway endpoint"
  value       = var.edge_gateway_instance_name
}

output "edge_gateway_demo_event_command" {
  description = "Command to generate controlled gateway/firewall/VPN telemetry"
  value       = var.enable_gcp_endpoints ? "gcloud compute ssh ${var.edge_gateway_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo /usr/local/bin/gateway-demo-generate-events.sh\"" : "docker compose -f docker-compose.endpoints.yml exec ${var.edge_gateway_instance_name} /usr/local/bin/gateway-demo-generate-events.sh"
}

output "edge_gateway_peer_config_command" {
  description = "Command to view the sample WireGuard peer config prepared on the edge gateway"
  value       = var.enable_gcp_endpoints ? "gcloud compute ssh ${var.edge_gateway_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo cat /opt/gateway-lab/sample-peer.conf\"" : "docker compose -f docker-compose.endpoints.yml exec ${var.edge_gateway_instance_name} cat /opt/gateway-lab/sample-peer.conf"
}

output "db_server_public_ip" {
  description = "Public IP of the monitored database endpoint"
  value       = var.enable_gcp_endpoints ? google_compute_instance.db_server[0].network_interface[0].access_config[0].nat_ip : null
}

output "db_server_agent_name" {
  description = "Agent name expected in the Wazuh dashboard for the database endpoint"
  value       = var.db_server_instance_name
}

output "db_demo_event_command" {
  description = "Command to generate controlled database telemetry"
  value       = var.enable_gcp_endpoints ? "gcloud compute ssh ${var.db_server_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo /usr/local/bin/db-demo-generate-events.sh\"" : "docker compose -f docker-compose.endpoints.yml exec ${var.db_server_instance_name} /usr/local/bin/db-demo-generate-events.sh"
}

output "docker_host_public_ip" {
  description = "Public IP of the monitored docker host endpoint"
  value       = var.enable_gcp_endpoints ? google_compute_instance.docker_host[0].network_interface[0].access_config[0].nat_ip : null
}

output "docker_host_agent_name" {
  description = "Agent name expected in the Wazuh dashboard for the docker host endpoint"
  value       = var.docker_host_instance_name
}

output "docker_host_app_url" {
  description = "Public URL of the sample portal hosted on the monitored docker host"
  value       = var.enable_gcp_endpoints ? "http://${google_compute_instance.docker_host[0].network_interface[0].access_config[0].nat_ip}:${var.docker_demo_port}" : "http://127.0.0.1:${var.docker_demo_port}"
}

output "docker_demo_event_command" {
  description = "Command to generate controlled container-host telemetry"
  value       = var.enable_gcp_endpoints ? "gcloud compute ssh ${var.docker_host_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo /usr/local/bin/docker-demo-generate-events.sh\"" : "docker compose -f docker-compose.endpoints.yml exec ${var.docker_host_instance_name} /usr/local/bin/docker-demo-generate-events.sh"
}

output "linux_ui_public_ip" {
  description = "Public IP of the monitored Linux UI endpoint"
  value       = var.enable_gcp_endpoints ? google_compute_instance.linux_ui_workstation[0].network_interface[0].access_config[0].nat_ip : null
}

output "linux_ui_private_ip" {
  description = "Private IP of the monitored Linux UI endpoint"
  value       = var.enable_gcp_endpoints ? google_compute_instance.linux_ui_workstation[0].network_interface[0].network_ip : "172.30.50.15"
}

output "linux_ui_agent_name" {
  description = "Agent name expected in the Wazuh dashboard for the Linux UI endpoint"
  value       = var.linux_ui_instance_name
}

output "linux_ui_rdp_credentials_command" {
  description = "Command to read the generated XRDP credentials for the Linux UI endpoint"
  value       = var.enable_gcp_endpoints ? "gcloud compute ssh ${var.linux_ui_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo cat /root/linux-ui-rdp-credentials.txt\"" : "docker compose -f docker-compose.endpoints.yml exec ${var.linux_ui_instance_name} cat /root/linux-ui-rdp-credentials.txt"
}

output "linux_ui_ransomware_demo_command" {
  description = "Command to generate controlled ransomware-like FIM burst telemetry on the Linux UI endpoint"
  value       = var.enable_gcp_endpoints ? "gcloud compute ssh ${var.linux_ui_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo /usr/local/bin/simulate-confidential-ransomware-burst.sh\"" : "docker compose -f docker-compose.endpoints.yml exec ${var.linux_ui_instance_name} /usr/local/bin/simulate-confidential-ransomware-burst.sh"
}

output "linux_ui_auth_failure_demo_command" {
  description = "Command to generate controlled failed authentication telemetry for user esquivel"
  value       = var.enable_gcp_endpoints ? "gcloud compute ssh ${var.linux_ui_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo /usr/local/bin/linux-ui-demo-auth-failure.sh\"" : "docker compose -f docker-compose.endpoints.yml exec ${var.linux_ui_instance_name} /usr/local/bin/linux-ui-demo-auth-failure.sh"
}

output "linux_ui_nmap_scan_from_metasploit_command" {
  description = "Command to run a controlled Nmap scan from the Metasploit endpoint against the Linux UI endpoint"
  value       = var.enable_gcp_endpoints ? "gcloud compute ssh ${var.metasploit_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo bash -lc 'command -v nmap >/dev/null 2>&1 || (apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y nmap); nmap -Pn -sS -T4 -p1-1024 ${google_compute_instance.linux_ui_workstation[0].network_interface[0].network_ip}'\"" : "docker compose -f docker-compose.endpoints.yml exec ${var.metasploit_instance_name} nmap -Pn -sS -T4 -p1-1024 linux-ui-workstation; docker compose -f docker-compose.endpoints.yml exec ${var.linux_ui_instance_name} /usr/local/bin/linux-ui-demo-portscan-log.sh"
}

output "windows_server_public_ip" {
  description = "Public IP of the monitored Windows Server endpoint"
  value       = var.enable_gcp_endpoints && var.enable_windows_server ? google_compute_instance.windows_server[0].network_interface[0].access_config[0].nat_ip : null
}

output "windows_server_agent_name" {
  description = "Agent name expected in the Wazuh dashboard for the Windows Server endpoint"
  value       = var.windows_instance_name
}

output "windows_demo_event_command" {
  description = "PowerShell command to generate controlled Windows endpoint telemetry over RDP or a Windows shell"
  value       = "powershell.exe -ExecutionPolicy Bypass -File C:\\ProgramData\\WazuhDemo\\Generate-WindowsDemoEvents.ps1"
}

output "windows_rdp_password_command" {
  description = "Command to set or reset the Windows Administrator password for RDP access"
  value       = "gcloud compute reset-windows-password ${var.windows_instance_name} --project=${var.project_id} --zone=${var.zone} --user=Administrator"
}

output "wazuh_target_agent_name" {
  description = "Agent name expected in the Wazuh dashboard"
  value       = var.target_instance_name
}

output "demo_event_command" {
  description = "Command to generate controlled demo telemetry on the monitored target"
  value       = var.enable_gcp_endpoints ? "gcloud compute ssh ${var.target_instance_name} --project=${var.project_id} --zone=${var.zone} --command=\"sudo /usr/local/bin/pyme-demo-generate-events.sh\"" : "docker compose -f docker-compose.endpoints.yml exec ${var.target_instance_name} /usr/local/bin/pyme-demo-generate-events.sh"
}
