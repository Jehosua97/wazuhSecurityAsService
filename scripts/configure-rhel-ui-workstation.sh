#!/usr/bin/env bash

set -euo pipefail

LAB_USER="${LAB_USER:-esquivel}"
RHEL_UI_HOST="${RHEL_UI_HOST:-rhel-ui-workstation}"
PASSWORD_FILE="${PASSWORD_FILE:-/root/rhel-ui-rdp-credentials.txt}"
RDP_PORT="${RDP_PORT:-3389}"
SENSITIVE_DIR="${SENSITIVE_DIR:-/home/$LAB_USER/Confidencial}"
LOG_FILE="${LOG_FILE:-/var/log/rhel-ui-workstation-setup.log}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script with sudo on the RHEL UI endpoint."
    exit 1
fi

touch "$LOG_FILE"
chmod 0644 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting RHEL UI workstation setup for $RHEL_UI_HOST..."

install_desktop_packages() {
    echo "Refreshing package metadata..."
    dnf -y makecache

    echo "Installing DNF helpers and enabling EPEL for XRDP..."
    dnf -y install dnf-plugins-core curl openssl rsyslog firewalld
    dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm" || true

    local arch
    arch="$(arch)"
    dnf config-manager --set-enabled "codeready-builder-for-rhel-9-${arch}-rpms" >/dev/null 2>&1 || true
    dnf config-manager --set-enabled "rhui-codeready-builder-for-rhel-9-${arch}-rpms" >/dev/null 2>&1 || true

    echo "Installing graphical desktop and XRDP packages..."
    dnf -y groupinstall "Server with GUI"
    dnf -y install \
        dbus-x11 \
        gdm \
        gnome-session \
        tigervnc-server \
        xorg-x11-server-Xorg \
        xorg-x11-xinit \
        xrdp
}

create_demo_user() {
    echo "Creating or updating demo user $LAB_USER..."
    if ! id "$LAB_USER" >/dev/null 2>&1; then
        useradd -m -s /bin/bash "$LAB_USER"
    fi

    local password
    password="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)Aa1!"
    echo "$LAB_USER:$password" | chpasswd
    usermod -aG wheel "$LAB_USER"

    mkdir -p "/home/$LAB_USER/.config" "/home/$LAB_USER/Desktop" "/home/$LAB_USER/Documents" "$SENSITIVE_DIR"
    echo "gnome-session" >"/home/$LAB_USER/.Xclients"
    chmod +x "/home/$LAB_USER/.Xclients"
    touch "/home/$LAB_USER/.config/gnome-initial-setup-done"
    ln -sfn "$SENSITIVE_DIR" "/home/$LAB_USER/Desktop/Confidencial"
    ln -sfn "$SENSITIVE_DIR" "/home/$LAB_USER/Documents/Confidencial"
    chown -R "$LAB_USER:$LAB_USER" "/home/$LAB_USER"

    cat >"$SENSITIVE_DIR/README-demo.txt" <<EOF
Carpeta sensible de demostracion para $RHEL_UI_HOST.
Usala para mostrar cambios visuales en el endpoint Red Hat con interfaz grafica.
EOF
    chown "$LAB_USER:$LAB_USER" "$SENSITIVE_DIR/README-demo.txt"
    chmod 0660 "$SENSITIVE_DIR/README-demo.txt"

    cat >"$PASSWORD_FILE" <<EOF
rhel_ui_host=$RHEL_UI_HOST
rdp_user=$LAB_USER
rdp_password=$password
rdp_port=$RDP_PORT
sensitive_folder=$SENSITIVE_DIR
EOF
    chmod 0600 "$PASSWORD_FILE"
}

enable_remote_desktop() {
    echo "Enabling graphical target, GDM, XRDP and firewall..."
    systemctl set-default graphical.target
    systemctl enable --now firewalld
    firewall-cmd --permanent --add-port="${RDP_PORT}/tcp"
    firewall-cmd --reload

    systemctl enable --now gdm
    systemctl enable --now xrdp
    systemctl restart xrdp
}

install_desktop_packages
create_demo_user
enable_remote_desktop

echo "RHEL UI workstation setup completed."
echo "Credentials file: $PASSWORD_FILE"
