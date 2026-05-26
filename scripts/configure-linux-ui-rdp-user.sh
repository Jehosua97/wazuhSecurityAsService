#!/usr/bin/env bash

set -euo pipefail

LAB_USER="${LAB_USER:-esquivel}"
SENSITIVE_DIR="${SENSITIVE_DIR:-/home/$LAB_USER/Confidencial}"
PASSWORD_FILE="${PASSWORD_FILE:-/root/linux-ui-rdp-credentials.txt}"
RDP_PORT="${RDP_PORT:-3389}"
LINUX_UI_HOST="${LINUX_UI_HOST:-linux-ui-workstation}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script with sudo on the Linux UI endpoint."
    exit 1
fi

if ! id "$LAB_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$LAB_USER"
fi

LAB_PASSWORD="$(python3 - <<'PY'
import secrets
import string

alphabet = string.ascii_letters + string.digits
print("".join(secrets.choice(alphabet) for _ in range(16)) + "Aa1!")
PY
)"
echo "$LAB_USER:$LAB_PASSWORD" | chpasswd
usermod -aG sudo,adm "$LAB_USER" 2>/dev/null || true

echo "xfce4-session" >"/home/$LAB_USER/.xsession"
chown "$LAB_USER:$LAB_USER" "/home/$LAB_USER/.xsession"

cat >"$PASSWORD_FILE" <<EOF
linux_ui_host=$LINUX_UI_HOST
rdp_user=$LAB_USER
rdp_password=$LAB_PASSWORD
rdp_port=$RDP_PORT
sensitive_folder=$SENSITIVE_DIR
documents_shortcut=/home/$LAB_USER/Documents/Confidencial
EOF
chmod 600 "$PASSWORD_FILE"

echo "RDP user ready: $LAB_USER"
echo "Credential file: $PASSWORD_FILE"
