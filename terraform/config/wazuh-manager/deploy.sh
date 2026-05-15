#!/bin/bash

set -euo pipefail

# Get the container ID
CONTAINER_ID=$(sudo docker ps -q --filter "name=manager")

if [ -z "$CONTAINER_ID" ]; then
    echo "Error: Wazuh manager container not found"
    exit 1
fi

WAZUH_ETC_DIR="/var/lib/docker/volumes/single-node_wazuh_etc/_data"
if [ ! -d "$WAZUH_ETC_DIR" ]; then
    WAZUH_ETC_VOLUME=$(sudo docker volume ls --format '{{.Name}}' | grep 'wazuh_etc$' | head -n 1 || true)
    if [ -z "$WAZUH_ETC_VOLUME" ]; then
        echo "Error: Wazuh etc Docker volume not found"
        exit 1
    fi
    WAZUH_ETC_DIR="/var/lib/docker/volumes/$WAZUH_ETC_VOLUME/_data"
fi

echo "Applying Wazuh PYME Mexico manager configuration to $WAZUH_ETC_DIR"
sudo mkdir -p "$WAZUH_ETC_DIR/rules" "$WAZUH_ETC_DIR/lists"
sudo install -m 0640 /tmp/wazuh-manager/etc/ossec.conf "$WAZUH_ETC_DIR/ossec.conf"
sudo install -m 0640 /tmp/wazuh-manager/etc/rules/local_rules.xml "$WAZUH_ETC_DIR/rules/local_rules.xml"
sudo install -m 0640 /tmp/wazuh-manager/etc/lists/alienvault_reputation.ipset "$WAZUH_ETC_DIR/lists/alienvault_reputation.ipset"
sudo sed -i 's/\r$//' "$WAZUH_ETC_DIR/ossec.conf"
sudo sed -i 's/\r$//' "$WAZUH_ETC_DIR/rules/local_rules.xml"
sudo sed -i 's/\r$//' "$WAZUH_ETC_DIR/lists/alienvault_reputation.ipset"

sudo docker exec -i $CONTAINER_ID mkdir -p /opt/tools
sudo docker cp /tmp/wazuh-manager/opt/tools/iplist-to-cdblist.py $CONTAINER_ID:/opt/tools/iplist-to-cdblist.py
# Convert ipset to CDB list
sudo docker exec -i $CONTAINER_ID /var/ossec/framework/python/bin/python3 /opt/tools/iplist-to-cdblist.py \
    /var/ossec/etc/lists/alienvault_reputation.ipset \
    /var/ossec/etc/lists/blacklist-alienvault

# Fix permissions
sudo docker exec -i $CONTAINER_ID chown wazuh:wazuh /var/ossec/etc/ossec.conf
sudo docker exec -i $CONTAINER_ID chown wazuh:wazuh /var/ossec/etc/rules/local_rules.xml
sudo docker exec -i $CONTAINER_ID chown wazuh:wazuh /var/ossec/etc/lists/alienvault_reputation.ipset
sudo docker exec -i $CONTAINER_ID chown wazuh:wazuh /var/ossec/etc/lists/blacklist-alienvault

# Restart Wazuh controller
sudo docker exec -i $CONTAINER_ID /var/ossec/bin/wazuh-control restart

echo "Wazuh PYME Mexico rules, threat-intel list and compliance tuning applied."
