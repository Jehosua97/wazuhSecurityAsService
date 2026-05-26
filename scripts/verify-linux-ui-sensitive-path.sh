#!/usr/bin/env bash

set -euo pipefail

LAB_USER="${LAB_USER:-esquivel}"
SENSITIVE_DIR="${SENSITIVE_DIR:-/home/$LAB_USER/Confidencial}"
TEST_FILE="$SENSITIVE_DIR/redhat-ui-fim-test.txt"
CONFIG_FILE="${CONFIG_FILE:-/var/ossec/etc/ossec.conf}"

mkdir -p "$SENSITIVE_DIR"
chown root:"$LAB_USER" "$SENSITIVE_DIR" 2>/dev/null || true
chmod 0770 "$SENSITIVE_DIR" 2>/dev/null || true
echo "monitored_at=$(date -Iseconds)" >>"$TEST_FILE"
chown root:"$LAB_USER" "$TEST_FILE" 2>/dev/null || true
chmod 0660 "$TEST_FILE" 2>/dev/null || true

echo "wazuh_agent_status=$(systemctl is-active wazuh-agent || true)"
echo "configured_paths:"
grep -n "$SENSITIVE_DIR" "$CONFIG_FILE" || true
echo "filesystem:"
ls -ld "$SENSITIVE_DIR" /Confidencial 2>/dev/null || true
echo "test_file=$TEST_FILE"
