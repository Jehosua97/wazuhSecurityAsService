provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Private demo network for the managed Wazuh PYME offering.
resource "google_compute_network" "vpc_wazuh" {
  name                    = "vpc-wazuh"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "Wazuh VPC"
  mtu                     = 1460
}

resource "google_compute_subnetwork" "vpc_wazuh_subnet" {
  name          = "vpc-wazuh-subnet"
  region        = var.region
  network       = google_compute_network.vpc_wazuh.self_link
  ip_cidr_range = "10.0.1.0/24"
  depends_on    = [google_compute_network.vpc_wazuh]
}

# Wazuh single-node manager used as the managed SIEM/XDR control plane.
resource "google_compute_instance" "wazuh_server" {
  name         = "wazuh-server"
  machine_type = var.wazuh_machine_type
  zone         = var.zone

  labels = {
    environment = var.environment
    solution    = "wazuh-pyme-mx"
    role        = "manager"
  }

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    network    = google_compute_network.vpc_wazuh.self_link
    subnetwork = google_compute_subnetwork.vpc_wazuh_subnet.self_link
    access_config {}
  }

  tags = ["wazuh-manager", "managed-siem"]

  metadata_startup_script = file("./scripts/startup.sh")
}

# Agents register and send telemetry to the manager from the demo subnet and any explicitly allowed external ranges.
resource "google_compute_firewall" "wazuh_agent_firewall" {
  name    = "wazuh-agent-ingress"
  network = google_compute_network.vpc_wazuh.self_link

  allow {
    protocol = "tcp"
    ports    = ["1514", "1515", "1516", "55000"]
  }

  source_ranges = concat(
    [google_compute_subnetwork.vpc_wazuh_subnet.ip_cidr_range],
    var.extra_agent_source_ranges
  )
  target_tags   = ["wazuh-manager"]
}

# Public dashboard access for demos. Restrict admin_source_ranges before production use.
resource "google_compute_firewall" "wazuh_dashboard_firewall" {
  name    = "wazuh-dashboard-ingress"
  network = google_compute_network.vpc_wazuh.self_link

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = var.admin_source_ranges
  target_tags   = ["wazuh-manager"]
}

# SSH is kept separate from product ports so demos can be locked down quickly.
resource "google_compute_firewall" "admin_ssh_firewall" {
  name    = "wazuh-admin-ssh-ingress"
  network = google_compute_network.vpc_wazuh.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.admin_source_ranges
  target_tags   = ["wazuh-manager", "vulnerable-target", "metasploit-endpoint", "edge-gateway", "db-server", "docker-host"]
}

# Monitored target used to demonstrate the free scan, FIM, SCA, web attacks and compliance evidence.
resource "google_compute_instance" "ubuntu_endpoint" {
  name         = var.target_instance_name
  machine_type = var.target_machine_type
  zone         = var.zone

  labels = {
    environment = var.environment
    solution    = "wazuh-pyme-mx"
    role        = "demo-target"
  }

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    network    = google_compute_network.vpc_wazuh.self_link
    subnetwork = google_compute_subnetwork.vpc_wazuh_subnet.self_link
    access_config {}
  }

  tags = ["vulnerable-target", "pyme-demo"]

  metadata_startup_script = templatefile("./scripts/vulnerable_target_startup.sh.tftpl", {
    wazuh_manager_ip   = google_compute_instance.wazuh_server.network_interface[0].network_ip
    wazuh_agent_name   = var.target_instance_name
    juice_shop_port    = var.juice_shop_port
    wazuh_version      = var.wazuh_version
    demo_company_name  = var.demo_company_name
    compliance_profile = var.compliance_profile
  })
}

# Monitored Metasploit endpoint used as an offensive workstation inside the lab.
resource "google_compute_instance" "metasploit_endpoint" {
  name         = var.metasploit_instance_name
  machine_type = var.metasploit_machine_type
  zone         = var.zone

  labels = {
    environment = var.environment
    solution    = "wazuh-pyme-mx"
    role        = "metasploit-endpoint"
  }

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 40
    }
  }

  network_interface {
    network    = google_compute_network.vpc_wazuh.self_link
    subnetwork = google_compute_subnetwork.vpc_wazuh_subnet.self_link
    access_config {}
  }

  tags = ["metasploit-endpoint", "red-team-lab"]

  metadata_startup_script = templatefile("./scripts/metasploit_target_startup.sh.tftpl", {
    wazuh_manager_ip         = google_compute_instance.wazuh_server.network_interface[0].network_ip
    wazuh_agent_name         = var.metasploit_instance_name
    wazuh_version            = var.wazuh_version
    metasploit_workspace_name = var.metasploit_workspace_name
  })
}

# Monitored edge gateway endpoint with firewall and VPN telemetry.
resource "google_compute_instance" "edge_gateway" {
  name         = var.edge_gateway_instance_name
  machine_type = var.edge_gateway_machine_type
  zone         = var.zone

  labels = {
    environment = var.environment
    solution    = "wazuh-pyme-mx"
    role        = "edge-gateway"
  }

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network    = google_compute_network.vpc_wazuh.self_link
    subnetwork = google_compute_subnetwork.vpc_wazuh_subnet.self_link
    access_config {}
  }

  tags = ["edge-gateway", "network-edge"]

  metadata_startup_script = templatefile("./scripts/edge_gateway_startup.sh.tftpl", {
    wazuh_manager_ip = google_compute_instance.wazuh_server.network_interface[0].network_ip
    wazuh_agent_name = var.edge_gateway_instance_name
    wazuh_version    = var.wazuh_version
    wireguard_port   = var.wireguard_port
  })
}

# Monitored internal database endpoint.
resource "google_compute_instance" "db_server" {
  name         = var.db_server_instance_name
  machine_type = var.db_server_machine_type
  zone         = var.zone

  labels = {
    environment = var.environment
    solution    = "wazuh-pyme-mx"
    role        = "db-server"
  }

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    network    = google_compute_network.vpc_wazuh.self_link
    subnetwork = google_compute_subnetwork.vpc_wazuh_subnet.self_link
    access_config {}
  }

  tags = ["db-server", "data-tier"]

  metadata_startup_script = templatefile("./scripts/db_server_startup.sh.tftpl", {
    wazuh_manager_ip = google_compute_instance.wazuh_server.network_interface[0].network_ip
    wazuh_agent_name = var.db_server_instance_name
    wazuh_version    = var.wazuh_version
    db_name          = var.db_name
  })
}

# Monitored docker host endpoint with sample business containers.
resource "google_compute_instance" "docker_host" {
  name         = var.docker_host_instance_name
  machine_type = var.docker_host_machine_type
  zone         = var.zone

  labels = {
    environment = var.environment
    solution    = "wazuh-pyme-mx"
    role        = "docker-host"
  }

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    network    = google_compute_network.vpc_wazuh.self_link
    subnetwork = google_compute_subnetwork.vpc_wazuh_subnet.self_link
    access_config {}
  }

  tags = ["docker-host", "container-platform"]

  metadata_startup_script = templatefile("./scripts/docker_host_startup.sh.tftpl", {
    wazuh_manager_ip = google_compute_instance.wazuh_server.network_interface[0].network_ip
    wazuh_agent_name = var.docker_host_instance_name
    wazuh_version    = var.wazuh_version
    docker_demo_port = var.docker_demo_port
  })
}

# Public access to the landing page and Juice Shop lab for sales demos.
resource "google_compute_firewall" "target_lab_firewall" {
  name    = "target-lab-firewall"
  network = google_compute_network.vpc_wazuh.self_link

  allow {
    protocol = "tcp"
    ports    = ["80", format("%d", var.juice_shop_port)]
  }

  source_ranges = var.target_source_ranges
  target_tags   = ["vulnerable-target"]
}

# Public WireGuard listener for the monitored edge gateway lab.
resource "google_compute_firewall" "edge_gateway_vpn_firewall" {
  name    = "edge-gateway-vpn-ingress"
  network = google_compute_network.vpc_wazuh.self_link

  allow {
    protocol = "udp"
    ports    = [format("%d", var.wireguard_port)]
  }

  source_ranges = var.admin_source_ranges
  target_tags   = ["edge-gateway"]
}

# Internal database access for workloads inside the lab.
resource "google_compute_firewall" "db_internal_firewall" {
  name    = "db-internal-ingress"
  network = google_compute_network.vpc_wazuh.self_link

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }

  source_ranges = [google_compute_subnetwork.vpc_wazuh_subnet.ip_cidr_range]
  target_tags   = ["db-server"]
}

# Public access to the sample portal on the monitored docker host.
resource "google_compute_firewall" "docker_host_demo_firewall" {
  name    = "docker-host-demo-ingress"
  network = google_compute_network.vpc_wazuh.self_link

  allow {
    protocol = "tcp"
    ports    = [format("%d", var.docker_demo_port)]
  }

  source_ranges = var.admin_source_ranges
  target_tags   = ["docker-host"]
}

