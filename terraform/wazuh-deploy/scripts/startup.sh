#!/bin/bash

WAZUH_DOCKER_VERSION="v4.13.0"

# GENERAL TOOLS DIRECTORY
TOOLS_DIR="/opt/tools"
mkdir -p "$TOOLS_DIR"

# Log all output to a plain file so failures are easy to inspect on the VM.
LOG_FILE="/var/log/startup.log"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"
exec >>"$LOG_FILE" 2>&1
# Function to handle errors
handle_error() {
    echo "Error on line $1"
    exit 1
}
trap 'handle_error $LINENO' ERR

echo "Starting Wazuh managed PYME demo installation..."
echo "Wazuh Docker version: $WAZUH_DOCKER_VERSION"


# Update packages
sudo apt-get update

# Install Docker
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    docker.io \
    docker-compose \
    git
# Enable and start Docker service
echo "Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Clone Wazuh Docker Repository
REPO_DIR="/opt/wazuh-docker"
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning Wazuh Docker repository..."
    sudo git clone https://github.com/wazuh/wazuh-docker.git -b "$WAZUH_DOCKER_VERSION" "$REPO_DIR"
else
    echo "Wazuh Docker repository already exists, reusing pinned version $WAZUH_DOCKER_VERSION."
    sudo git -C "$REPO_DIR" fetch --tags origin "$WAZUH_DOCKER_VERSION" || true
    sudo git -C "$REPO_DIR" checkout "$WAZUH_DOCKER_VERSION"
fi

# Adjust kernel parameters
echo "Configuring kernel parameters..."
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf > /dev/null


# Navigate to the single-node directory and start services
echo "Starting Wazuh services..."
cd "$REPO_DIR/single-node"

# Generate certificates
echo "Generating certificates..."
sudo docker-compose -f generate-indexer-certs.yml run --rm generator

# Start services
echo "Starting Wazuh services..."
sudo docker-compose up -d

# Verify Docker containers are running
echo "Verifying Docker containers..."
if sudo docker ps | grep -q wazuh; then
    echo "Wazuh installation and startup successful!"
else
    echo "Wazuh services failed to start. Check the logs for details."
    exit 1
fi

# Create the tools directory in the container:  
MANAGER_CONTAINER_ID=$(sudo docker ps -q --filter "name=manager")
sudo docker exec -i $MANAGER_CONTAINER_ID mkdir -p /opt/tools

cat >/opt/wazuh-pyme-demo.txt <<EOF
Wazuh PYME Mexico demo
======================
Profile: Managed SIEM/XDR for Mexican SMBs
Focus: LFPDPPP, PCI-DSS v4.0, ISO 27001:2022 evidence
Version: $WAZUH_DOCKER_VERSION

Next step:
Copy terraform/config/wazuh-manager to /tmp/wazuh-manager and run deploy.sh
to apply local rules, threat-intel lists and compliance tuning.
EOF
