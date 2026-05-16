#!/usr/bin/env bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script with sudo on the Linux UI endpoint."
    exit 1
fi

SENSITIVE_DIR="${SENSITIVE_DIR:-/Confidencial}"
CONFIG_FILE="${CONFIG_FILE:-/var/ossec/etc/ossec.conf}"
ENABLE_FIREWALL_DROP="${ENABLE_FIREWALL_DROP:-yes}"
DESKTOP_USER="${DESKTOP_USER:-${SUDO_USER:-}}"

if [ -z "$DESKTOP_USER" ] || [ "$DESKTOP_USER" = "root" ]; then
    DESKTOP_USER="$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)"
fi

USER_HOME="$(getent passwd "$DESKTOP_USER" | cut -d: -f6)"
DOCUMENTS_DIR="$USER_HOME/Documentos"
if [ ! -d "$DOCUMENTS_DIR" ] && [ -d "$USER_HOME/Documents" ]; then
    DOCUMENTS_DIR="$USER_HOME/Documents"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Wazuh agent config not found at $CONFIG_FILE"
    echo "Install and enroll the Wazuh agent before running this script."
    exit 1
fi

echo "Preparing sensitive folder at $SENSITIVE_DIR"
mkdir -p "$SENSITIVE_DIR"
chown root:"$DESKTOP_USER" "$SENSITIVE_DIR" 2>/dev/null || chown root:root "$SENSITIVE_DIR"
chmod 0770 "$SENSITIVE_DIR"

if [ -n "$USER_HOME" ]; then
    mkdir -p "$DOCUMENTS_DIR"
    chown "$DESKTOP_USER":"$DESKTOP_USER" "$DOCUMENTS_DIR" 2>/dev/null || true
    ln -sfn "$SENSITIVE_DIR" "$DOCUMENTS_DIR/Confidencial"
    chown -h "$DESKTOP_USER":"$DESKTOP_USER" "$DOCUMENTS_DIR/Confidencial" 2>/dev/null || true
fi

echo "Updating Wazuh agent config at $CONFIG_FILE"
cp -a "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
tmp_config="$(mktemp)"
awk '
    /<!-- WAZUH_CONFIDENTIAL_LAB_START -->/ { skip=1; next }
    /<!-- WAZUH_CONFIDENTIAL_LAB_END -->/ { skip=0; next }
    !skip { print }
' "$CONFIG_FILE" > "$tmp_config"
cat "$tmp_config" > "$CONFIG_FILE"
rm -f "$tmp_config"

cat >> "$CONFIG_FILE" <<EOF
<!-- WAZUH_CONFIDENTIAL_LAB_START -->
<ossec_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/kern.log</location>
  </localfile>

  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    <auto_ignore frequency="10" timeframe="3600">no</auto_ignore>
    <directories realtime="yes" report_changes="yes" check_all="yes">$SENSITIVE_DIR</directories>
  </syscheck>
</ossec_config>
<!-- WAZUH_CONFIDENTIAL_LAB_END -->
EOF

if getent group wazuh >/dev/null; then
    chown root:wazuh "$CONFIG_FILE"
else
    chown root:root "$CONFIG_FILE"
fi
chmod 0640 "$CONFIG_FILE"

echo "Installing local ransomware-burst simulator"
install -m 0755 "$(dirname "$0")/simulate-confidential-ransomware-burst.sh" /usr/local/bin/simulate-confidential-ransomware-burst.sh

touch /var/log/kern.log
chmod 0640 /var/log/kern.log 2>/dev/null || true

if [ "$ENABLE_FIREWALL_DROP" = "yes" ]; then
    echo "Configuring nftables drop logging for lab port-scan detection"

    if ! command -v nft >/dev/null 2>&1; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y nftables
    fi

    systemctl enable --now nftables >/dev/null 2>&1 || true
    nft delete table inet wazuh_scan_lab >/dev/null 2>&1 || true
    nft add table inet wazuh_scan_lab
    nft 'add chain inet wazuh_scan_lab input { type filter hook input priority 0; policy accept; }'
    nft add rule inet wazuh_scan_lab input ct state established,related accept
    nft add rule inet wazuh_scan_lab input iif lo accept
    nft add rule inet wazuh_scan_lab input tcp dport 22 accept
    nft 'add rule inet wazuh_scan_lab input tcp dport { 1-21, 23-1024 } tcp flags & (fin|syn|rst|ack) == syn log prefix "wazuh-fw-drop: " level info drop'
fi

systemctl restart wazuh-agent

echo "Agent ready."
echo "Sensitive folder: $SENSITIVE_DIR"
echo "Documents shortcut: $DOCUMENTS_DIR/Confidencial"
echo "Ransomware simulation: sudo /usr/local/bin/simulate-confidential-ransomware-burst.sh"
echo "Port scan test from another machine: sudo nmap -Pn -sS -T4 -p1-1024 <AGENT_IP>"
