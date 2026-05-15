#!/bin/bash

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

echo "Starting Ubuntu endpoint setup..."

# Update packages
sudo apt-get update
sudo apt-get install -y apache2 curl

# Enable and start Apache service
sudo systemctl enable apache2
sudo systemctl start apache2
