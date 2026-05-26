#!/usr/bin/env bash

set -euo pipefail

STARTUP_LOG="/var/log/local-container-startup.log"
touch "$STARTUP_LOG"
exec > >(tee -a "$STARTUP_LOG") 2>&1

PROFILE="${ENDPOINT_PROFILE:?ENDPOINT_PROFILE is required}"
WAZUH_MANAGER_IP="${WAZUH_MANAGER_IP:?WAZUH_MANAGER_IP is required}"
WAZUH_AGENT_NAME="${WAZUH_AGENT_NAME:-$PROFILE}"
WAZUH_VERSION="${WAZUH_VERSION:-4.13.0-1}"

echo "Starting local Docker endpoint profile=$PROFILE agent=$WAZUH_AGENT_NAME manager=$WAZUH_MANAGER_IP"

ensure_log() {
    local path="$1"
    mkdir -p "$(dirname "$path")"
    touch "$path"
    chmod 664 "$path" || true
}

wait_for_manager() {
    for attempt in $(seq 1 90); do
        if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$WAZUH_MANAGER_IP/1515" 2>/dev/null; then
            echo "Wazuh manager authd is reachable."
            return 0
        fi

        echo "Waiting for Wazuh manager authd on $WAZUH_MANAGER_IP:1515 (attempt $attempt/90)..."
        sleep 10
    done

    echo "Timed out waiting for Wazuh manager authd."
    return 1
}

append_ossec_config() {
    local marker="$1"
    local body="$2"
    local config="/var/ossec/etc/ossec.conf"

    if [ ! -f "$config" ]; then
        echo "Wazuh agent config not found yet; skipping marker $marker"
        return 0
    fi

    if grep -q "<!-- $marker START -->" "$config"; then
        python3 - "$config" "$marker" <<'PYEOF'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
marker = re.escape(sys.argv[2])
text = path.read_text()
pattern = rf"\n?<!-- {marker} START -->.*?<!-- {marker} END -->\n?"
path.write_text(re.sub(pattern, "\n", text, flags=re.S))
PYEOF
    fi

    cat >>"$config" <<EOF
<!-- $marker START -->
$body
<!-- $marker END -->
EOF
}

ensure_wazuh_runtime_identity() {
    if [ ! -d /var/ossec ]; then
        return 0
    fi

    local wazuh_gid wazuh_uid
    wazuh_gid="$(stat -c '%g' /var/ossec/etc 2>/dev/null || stat -c '%g' /var/ossec 2>/dev/null || echo '')"
    wazuh_uid="$(stat -c '%u' /var/ossec/etc 2>/dev/null || stat -c '%u' /var/ossec 2>/dev/null || echo '')"

    if ! getent group wazuh >/dev/null 2>&1; then
        if [ -n "$wazuh_gid" ] && [ "$wazuh_gid" != "0" ] && ! getent group "$wazuh_gid" >/dev/null 2>&1; then
            groupadd -g "$wazuh_gid" wazuh || groupadd wazuh
        else
            groupadd wazuh || true
        fi
    fi

    if ! id wazuh >/dev/null 2>&1; then
        if [ -n "$wazuh_uid" ] && [ "$wazuh_uid" != "0" ] && ! getent passwd "$wazuh_uid" >/dev/null 2>&1; then
            useradd -r -u "$wazuh_uid" -g wazuh -d /var/ossec -s /usr/sbin/nologin wazuh || \
                useradd -r -g wazuh -d /var/ossec -s /usr/sbin/nologin wazuh
        else
            useradd -r -g wazuh -d /var/ossec -s /usr/sbin/nologin wazuh || true
        fi
    fi
}

write_module_demo_event() {
    local module="$1"
    local action="$2"
    local detail="$3"

    write_syslog_line "/var/log/wazuh-agent-modules-demo.log" "$WAZUH_AGENT_NAME" "wazuh-module-demo" "module=$module action=$action detail=$detail"
}

provision_agent_module_demo() {
    mkdir -p /opt/wazuh-module-demo/evidence /opt/wazuh-module-demo/config /var/ossec/etc/shared /var/ossec/active-response/bin
    ensure_log /var/log/wazuh-agent-modules-demo.log
    ensure_log /var/log/cloud-gcp-demo.log

    cat >/opt/wazuh-module-demo/config/module-baseline.conf <<EOF
endpoint=$WAZUH_AGENT_NAME
profile=$PROFILE
manager=$WAZUH_MANAGER_IP
log_collector=enabled
command_execution=enabled_local_only
fim=enabled
sca=enabled
syscollector=enabled
rootcheck=enabled
active_response=enabled_safe_evidence_only
container_security=$([ "$PROFILE" = "docker-host" ] && echo "docker_listener_enabled" || echo "not_applicable")
cloud_security=simulated_log_only
EOF

    cat >/usr/local/bin/wazuh-demo-command-disk.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
usage="$(df -P / | awk 'NR==2 {print $5}')"
available="$(df -P / | awk 'NR==2 {print $4}')"
echo "module=command action=disk_space_check filesystem=/ usage=$usage available_kb=$available"
EOF
    chmod +x /usr/local/bin/wazuh-demo-command-disk.sh

    cat >/usr/local/bin/wazuh-demo-command-users.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
count="$(awk -F: '$3 >= 1000 && $1 != "nobody" {c++} END {print c+0}' /etc/passwd)"
echo "module=command action=local_user_inventory users=$count"
EOF
    chmod +x /usr/local/bin/wazuh-demo-command-users.sh

    cat >/usr/local/bin/wazuh-demo-generate-module-events.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

MODULE_LOG="/var/log/wazuh-agent-modules-demo.log"
CLOUD_LOG="/var/log/cloud-gcp-demo.log"
EVIDENCE_DIR="/opt/wazuh-module-demo/evidence"
CONFIG_FILE="/opt/wazuh-module-demo/config/module-baseline.conf"
HOST="$(hostname)"

mkdir -p "$EVIDENCE_DIR" "$(dirname "$CONFIG_FILE")"
touch "$MODULE_LOG" "$CLOUD_LOG" "$CONFIG_FILE"

emit() {
    local module="$1"
    local action="$2"
    local detail="$3"
    printf '%s %s wazuh-module-demo: module=%s action=%s detail=%s\n' "$(date '+%b %e %H:%M:%S')" "$HOST" "$module" "$action" "$detail" >> "$MODULE_LOG"
}

emit_cloud() {
    local action="$1"
    local detail="$2"
    printf '%s %s gcp-demo: module=cloud_security action=%s detail=%s\n' "$(date '+%b %e %H:%M:%S')" "$HOST" "$action" "$detail" >> "$CLOUD_LOG"
}

emit log_collector app_log_ingested "source=/var/log/wazuh-agent-modules-demo.log"
emit command local_command_output "script=/usr/local/bin/wazuh-demo-command-disk.sh"
emit fim baseline_file_changed "file=$CONFIG_FILE"
emit sca policy_expected "policy=/var/ossec/etc/shared/wazuh_demo_sca.yml"
emit syscollector inventory_scan_expected "tables=packages,ports,processes,network"
emit malware_detection rootcheck_scan_expected "safe_demo=no_malware_created"
emit vulnerability_detection manager_uses_inventory "source=syscollector_packages"
emit active_response trigger_safe_response "response=module-demo-response evidence_only=true"
emit container_security docker_listener_expected "profile=docker-host socket=/var/run/docker.sock"
emit_cloud iam_policy_change "project=wazuh-iac-on-gcp resource=demo-service-account outcome=simulated"
emit_cloud compute_instance_stop "project=wazuh-iac-on-gcp instance=legacy-demo-vm outcome=simulated"

{
    echo "last_module_demo_run=$(date -Is)"
    echo "host=$HOST"
} >> "$CONFIG_FILE"

cat >"$EVIDENCE_DIR/module-demo-$(date +%Y%m%d%H%M%S).json" <<JSON
{
  "timestamp": "$(date -Is)",
  "host": "$HOST",
  "scope": "safe-demo",
  "modules": [
    "log_collector",
    "command",
    "fim",
    "sca",
    "syscollector",
    "malware_detection_rootcheck",
    "active_response",
    "container_security",
    "cloud_security",
    "vulnerability_detection"
  ],
  "note": "No exploitation, malware, persistence or third-party activity was performed."
}
JSON

echo "Safe Wazuh module demo events generated."
EOF
    chmod +x /usr/local/bin/wazuh-demo-generate-module-events.sh

    cat >/var/ossec/active-response/bin/module-demo-response.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

EVIDENCE_DIR="/opt/wazuh-module-demo/evidence"
MODULE_LOG="/var/log/wazuh-agent-modules-demo.log"
mkdir -p "$EVIDENCE_DIR"

payload="$(cat || true)"
stamp="$(date -Is)"
evidence_file="$EVIDENCE_DIR/active-response-$stamp.json"

cat >"$evidence_file" <<JSON
{
  "timestamp": "$stamp",
  "action": "module-demo-response",
  "mode": "evidence-only",
  "payload": $(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
}
JSON

printf '%s %s wazuh-module-demo: module=active_response action=evidence_collected detail=file=%s\n' "$(date '+%b %e %H:%M:%S')" "$(hostname)" "$evidence_file" >> "$MODULE_LOG"
exit 0
EOF
    chmod 750 /var/ossec/active-response/bin/module-demo-response.sh

    cat >/var/ossec/etc/shared/wazuh_demo_sca.yml <<'EOF'
policy:
  id: "wazuh_demo_agent_modules"
  file: "wazuh_demo_sca.yml"
  name: "Wazuh demo - Agent module baseline"
  description: "Safe checks for the local Docker Wazuh module demonstration."
  references:
    - "https://documentation.wazuh.com/current/user-manual/capabilities/sec-config-assessment/"

requirements:
  title: "Linux endpoint"
  description: "Run only when the endpoint exposes os-release."
  condition: all
  rules:
    - "f:/etc/os-release"

checks:
  - id: 100001
    title: "Demo module baseline file exists"
    description: "The endpoint has the controlled module baseline file used for FIM and reporting."
    rationale: "The demo must be deterministic and auditable."
    remediation: "Recreate the container with scripts/lab-master.ps1 -Action start-linux."
    condition: all
    rules:
      - "f:/opt/wazuh-module-demo/config/module-baseline.conf"

  - id: 100002
    title: "Demo module event log exists"
    description: "The endpoint has a controlled log source for Wazuh module visibility."
    rationale: "Log collection must be visible in the dashboard."
    remediation: "Run /usr/local/bin/wazuh-demo-generate-module-events.sh."
    condition: all
    rules:
      - "f:/var/log/wazuh-agent-modules-demo.log"

  - id: 100003
    title: "No demo secrets file is present"
    description: "The demo endpoint must not include a fake secret file outside evidence paths."
    rationale: "Avoid normalizing insecure credential placement."
    remediation: "Remove /opt/wazuh-module-demo/config/demo-secret.txt if present."
    condition: none
    rules:
      - "f:/opt/wazuh-module-demo/config/demo-secret.txt"
EOF
}

configure_common_wazuh_modules() {
    append_ossec_config "LOCAL_DOCKER_WAZUH_AGENT_MODULES" '<ossec_config>
  <labels>
    <label key="lab">wazuh-security-mvp</label>
    <label key="lab_profile">'$PROFILE'</label>
    <label key="module_catalog">agent-modules-demo</label>
  </labels>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/wazuh-agent-modules-demo.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/cloud-gcp-demo.log</location>
  </localfile>

  <wodle name="command">
    <disabled>no</disabled>
    <tag>wazuh_demo_disk</tag>
    <command>/usr/local/bin/wazuh-demo-command-disk.sh</command>
    <interval>2m</interval>
    <run_on_start>yes</run_on_start>
    <timeout>10</timeout>
  </wodle>
  <wodle name="command">
    <disabled>no</disabled>
    <tag>wazuh_demo_users</tag>
    <command>/usr/local/bin/wazuh-demo-command-users.sh</command>
    <interval>5m</interval>
    <run_on_start>yes</run_on_start>
    <timeout>10</timeout>
  </wodle>

  <wodle name="syscollector">
    <disabled>no</disabled>
    <interval>10m</interval>
    <scan_on_start>yes</scan_on_start>
    <hardware>yes</hardware>
    <os>yes</os>
    <network>yes</network>
    <packages>yes</packages>
    <ports all="yes">yes</ports>
    <processes>yes</processes>
    <synchronization>
      <max_eps>10</max_eps>
    </synchronization>
  </wodle>

  <sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
    <interval>6h</interval>
    <skip_nfs>yes</skip_nfs>
    <policies>
      <policy>/var/ossec/etc/shared/wazuh_demo_sca.yml</policy>
    </policies>
  </sca>

  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <check_dev>yes</check_dev>
    <check_sys>yes</check_sys>
    <check_pids>yes</check_pids>
    <check_ports>yes</check_ports>
    <check_if>yes</check_if>
    <frequency>3600</frequency>
    <rootkit_files>/var/ossec/etc/shared/rootkit_files.txt</rootkit_files>
    <rootkit_trojans>/var/ossec/etc/shared/rootkit_trojans.txt</rootkit_trojans>
    <skip_nfs>yes</skip_nfs>
  </rootcheck>

  <active-response>
    <disabled>no</disabled>
    <repeated_offenders>1,5,10</repeated_offenders>
  </active-response>
</ossec_config>'
}

configure_docker_listener_module() {
    if [ "$PROFILE" != "docker-host" ]; then
        return 0
    fi

    if [ ! -e /var/run/docker.sock ]; then
        write_module_demo_event "container_security" "docker_socket_missing" "mount=/var/run/docker.sock"
        return 0
    fi

    append_ossec_config "LOCAL_DOCKER_WAZUH_DOCKER_LISTENER" '<ossec_config>
  <wodle name="docker-listener">
    <disabled>no</disabled>
    <interval>2m</interval>
    <attempts>5</attempts>
    <run_on_start>yes</run_on_start>
  </wodle>
</ossec_config>'
}

install_wazuh_agent() {
    wait_for_manager

    if [ ! -x /var/ossec/bin/wazuh-control ]; then
        echo "Installing Wazuh agent..."
        curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH \
            | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
        chmod 644 /usr/share/keyrings/wazuh.gpg
        echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
            >/etc/apt/sources.list.d/wazuh.list

        apt-get update
        if ! WAZUH_MANAGER="$WAZUH_MANAGER_IP" \
             WAZUH_REGISTRATION_SERVER="$WAZUH_MANAGER_IP" \
             WAZUH_AGENT_NAME="$WAZUH_AGENT_NAME" \
             DEBIAN_FRONTEND=noninteractive apt-get install -y "wazuh-agent=$WAZUH_VERSION"; then
            echo "Pinned Wazuh agent $WAZUH_VERSION was unavailable. Installing latest 4.x agent."
            WAZUH_MANAGER="$WAZUH_MANAGER_IP" \
            WAZUH_REGISTRATION_SERVER="$WAZUH_MANAGER_IP" \
            WAZUH_AGENT_NAME="$WAZUH_AGENT_NAME" \
                DEBIAN_FRONTEND=noninteractive apt-get install -y wazuh-agent
        fi

        apt-mark hold wazuh-agent || true
    else
        echo "Wazuh agent already installed in this container volume."
    fi

    ensure_wazuh_runtime_identity

    if [ -f /var/ossec/etc/ossec.conf ]; then
        sed -i "0,/<address>.*<\/address>/s//<address>$WAZUH_MANAGER_IP<\/address>/" /var/ossec/etc/ossec.conf || true
    fi

    if [ ! -s /var/ossec/etc/client.keys ]; then
        echo "Registering agent name $WAZUH_AGENT_NAME"
        /var/ossec/bin/agent-auth -m "$WAZUH_MANAGER_IP" -A "$WAZUH_AGENT_NAME" || true
    fi
}

start_wazuh_agent() {
    echo "Starting Wazuh agent..."
    /var/ossec/bin/wazuh-control restart || /var/ossec/bin/wazuh-control start || true
}

write_syslog_line() {
    local path="$1"
    local host="$2"
    local program="$3"
    local message="$4"

    ensure_log "$path"
    printf '%s %s %s: %s\n' "$(date '+%b %e %H:%M:%S')" "$host" "$program" "$message" >>"$path"
}

configure_common_logs() {
    ensure_log /var/log/auth.log
    ensure_log /var/log/syslog
    ensure_log /var/log/kern.log
}

provision_pyme_demo_target() {
    local attack_log="/var/log/pyme-attack-panel.log"
    ensure_log "$attack_log"

    a2enmod alias cgid headers proxy proxy_http >/dev/null || true
    a2enconf serve-cgi-bin >/dev/null || true
    mkdir -p /var/www/panel /var/www/empty /opt/pyme-compliance/customer-data /opt/pyme-compliance/evidence /opt/lab-share

    cat >/opt/pyme-compliance/customer-data/clientes-demo.csv <<'EOF'
id,nombre,email,tipo_dato,proposito
1,Ana Demo,ana.demo@example.com,personal,crm
2,Carlos Demo,carlos.demo@example.com,personal,soporte
3,Patricia Demo,patricia.demo@example.com,personal,pagos
EOF

    cat >/opt/pyme-compliance/evidence/control-map.md <<EOF
# Control map

- LFPDPPP: evidencia de acceso y cambios a datos personales.
- PCI-DSS v4.0: logging, monitoreo de integridad y alertas de seguridad.
- ISO 27001:2022: controles de operacion, eventos e incidentes.
EOF
    echo "demo-lab-artifact" >/opt/lab-share/README.txt
    chmod -R 770 /opt/pyme-compliance /opt/lab-share

    cat >/var/www/panel/index.html <<'EOF'
<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Wazuh Docker Lab</title>
    <style>
      body { margin: 0; font-family: system-ui, sans-serif; background: #f6f3ed; color: #172018; }
      header, main { padding: 24px; }
      button, a { display: block; width: 100%; margin: 8px 0; padding: 12px; border: 0; border-radius: 8px; background: #172018; color: #fff; font-weight: 700; text-decoration: none; cursor: pointer; }
      .grid { display: grid; grid-template-columns: 360px 1fr; gap: 18px; }
      .panel { background: #fff; border: 1px solid #ddd3c2; border-radius: 8px; padding: 18px; }
      pre { background: #10150f; color: #d7f5d3; padding: 14px; border-radius: 8px; overflow: auto; min-height: 120px; }
      iframe { width: 100%; height: 720px; border: 1px solid #ddd3c2; border-radius: 8px; background: #fff; }
      @media (max-width: 900px) { .grid { grid-template-columns: 1fr; } }
    </style>
  </head>
  <body>
    <header><h1>Wazuh Docker Lab - PyME target</h1></header>
    <main class="grid">
      <section class="panel">
        <a href="/" target="_blank" rel="noreferrer">Abrir Juice Shop</a>
        <button onclick="runAttack('sqli_login')">SQLi login controlado</button>
        <button onclick="runAttack('xss_search')">XSS search probe</button>
        <button onclick="runAttack('api_probe')">Recon API</button>
        <button onclick="runAttack('fim_change')">Cambio FIM</button>
        <button onclick="runAttack('run_all')">Ejecutar todo</button>
        <h2>Resultado</h2>
        <pre id="result">Listo.</pre>
        <h2>Historial</h2>
        <pre id="history">Cargando...</pre>
      </section>
      <iframe src="/" title="Juice Shop"></iframe>
    </main>
    <script>
      async function runAttack(action) {
        const response = await fetch('/cgi-bin/juicy-attack.py?action=' + encodeURIComponent(action), { cache: 'no-store' });
        document.getElementById('result').textContent = JSON.stringify(await response.json(), null, 2);
        loadHistory();
      }
      async function loadHistory() {
        const response = await fetch('/cgi-bin/juicy-attack.py?action=history', { cache: 'no-store' });
        const data = await response.json();
        document.getElementById('history').textContent = data.lines.join('\n') || 'Sin eventos todavia.';
      }
      loadHistory();
      setInterval(loadHistory, 8000);
    </script>
  </body>
</html>
EOF

    cat >/etc/apache2/sites-available/000-default.conf <<'EOF'
<VirtualHost *:80>
    DocumentRoot /var/www/empty
    ProxyRequests Off
    ProxyPreserveHost On
    ProxyPass /panel !
    ProxyPass /cgi-bin !
    ProxyPass / http://juice-shop:3000/ retry=0 connectiontimeout=5 timeout=30
    ProxyPassReverse / http://juice-shop:3000/
    Alias /panel /var/www/panel
    <Directory /var/www/panel>
        Require all granted
        DirectoryIndex index.html
    </Directory>
    ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
    <Directory /usr/lib/cgi-bin>
        Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
        Require all granted
    </Directory>
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOF

    cat >/usr/lib/cgi-bin/juicy-attack.py <<'PYEOF'
#!/usr/bin/env python3
import datetime
import json
import os
import urllib.error
import urllib.parse
import urllib.request

JUICE_URL = "http://juice-shop:3000"
ATTACK_LOG = "/var/log/pyme-attack-panel.log"
EVIDENCE_FILE = "/opt/pyme-compliance/evidence/attack-panel-evidence.log"
HOST = "pyme-demo-target"

def response(payload, status="200 OK"):
    print(f"Status: {status}")
    print("Content-Type: application/json")
    print("Cache-Control: no-store")
    print()
    print(json.dumps(payload, indent=2, ensure_ascii=True))

def syslog_date():
    return datetime.datetime.now().strftime("%b %e %H:%M:%S")

def iso_date():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def log_line(action, outcome, detail):
    safe_detail = detail.replace("\n", " ").replace('"', "'")[:500]
    line = f"{syslog_date()} {HOST} pyme-attack-panel: action={action} outcome={outcome} detail={safe_detail}"
    with open(ATTACK_LOG, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")
    return line

def http_call(method, path, body=None):
    data = None
    headers = {}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(JUICE_URL + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return {"method": method, "path": path, "status": resp.status}
    except urllib.error.HTTPError as exc:
        return {"method": method, "path": path, "status": exc.code}
    except Exception as exc:
        return {"method": method, "path": path, "status": "error", "detail": str(exc)}

def history():
    if not os.path.exists(ATTACK_LOG):
        return {"lines": []}
    with open(ATTACK_LOG, "r", encoding="utf-8", errors="replace") as fh:
        return {"lines": [line.rstrip("\n") for line in fh.readlines()[-40:]]}

def run(action):
    if action == "sqli_login":
        result = http_call("POST", "/rest/user/login", {"email": "' OR 1=1--", "password": "demo"})
        log_line(action, "completed", f"POST /rest/user/login returned {result['status']}")
        return {"requests": [result]}
    if action == "xss_search":
        result = http_call("GET", "/rest/products/search?q=%3Cscript%3Ealert('wazuh-demo')%3C/script%3E")
        log_line(action, "completed", f"GET /rest/products/search returned {result['status']}")
        return {"requests": [result]}
    if action == "api_probe":
        results = [http_call("GET", "/api/Challenges"), http_call("GET", "/rest/products/search?q=admin")]
        log_line(action, "completed", "API reconnaissance completed")
        return {"requests": results}
    if action == "fim_change":
        os.makedirs(os.path.dirname(EVIDENCE_FILE), exist_ok=True)
        with open(EVIDENCE_FILE, "a", encoding="utf-8") as fh:
            fh.write(f"{iso_date()} attack-panel changed compliance evidence\n")
        log_line(action, "completed", f"Updated {EVIDENCE_FILE}")
        return {"file": EVIDENCE_FILE, "status": "updated"}
    if action == "run_all":
        return {"results": [run("sqli_login"), run("xss_search"), run("api_probe"), run("fim_change")]}
    if action == "history":
        return history()
    log_line(action, "rejected", "Unknown action requested")
    return {"error": "unknown action"}

try:
    query = urllib.parse.parse_qs(os.environ.get("QUERY_STRING", ""))
    action = query.get("action", ["history"])[0]
    payload = run(action)
    payload["action"] = action
    payload["timestamp"] = iso_date()
    response(payload)
except Exception as exc:
    log_line("internal_error", "failed", str(exc))
    response({"error": str(exc)}, "500 Internal Server Error")
PYEOF
    chmod 755 /usr/lib/cgi-bin/juicy-attack.py

    cat >/usr/local/bin/pyme-demo-generate-events.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$(date '+%b %e %H:%M:%S') pyme-demo-target sshd[4242]: Failed password for invalid user admin from 203.0.113.66 port 49152 ssh2" >> /var/log/auth.log
echo "203.0.113.66 - - [$(date '+%d/%b/%Y:%H:%M:%S %z')] \"GET /rest/user/login?email=admin@example.com'OR'1'='1 HTTP/1.1\" 401 512" >> /var/log/apache2/access.log
echo "$(date '+%b %e %H:%M:%S') pyme-demo-target pyme-attack-panel: action=scripted_demo outcome=completed detail=manual_event_generator_ran" >> /var/log/pyme-attack-panel.log
echo "Demo compliance evidence changed at $(date -Is)" >> /opt/pyme-compliance/evidence/access-review.log
echo "temporary-public-share=$(date -Is)" >> /opt/lab-share/README.txt
chmod 666 /opt/pyme-compliance/customer-data/clientes-demo.csv
echo "Events generated."
EOF
    chmod +x /usr/local/bin/pyme-demo-generate-events.sh

    apachectl -DFOREGROUND &
}

configure_pyme_demo_target() {
    append_ossec_config "LOCAL_DOCKER_PYME_TARGET" '<ossec_config>
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/access.log</location>
  </localfile>
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/error.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/pyme-attack-panel.log</location>
  </localfile>
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    <directories realtime="yes" report_changes="yes">/opt/pyme-compliance</directories>
    <directories realtime="yes" report_changes="yes">/var/www/panel</directories>
    <directories realtime="yes" report_changes="yes">/opt/wazuh-module-demo</directories>
    <directories realtime="yes">/opt/lab-share</directories>
  </syscheck>
</ossec_config>'
}

provision_metasploit_node() {
    local msf_log="/var/log/metasploit-lab.log"
    ensure_log "$msf_log"
    mkdir -p "/opt/metasploit-lab/workspaces/${METASPLOIT_WORKSPACE_NAME:-customer_pyme_demo}"
    cat >"/opt/metasploit-lab/workspaces/${METASPLOIT_WORKSPACE_NAME:-customer_pyme_demo}/engagement-notes.md" <<EOF
# Engagement notes

- Workspace: ${METASPLOIT_WORKSPACE_NAME:-customer_pyme_demo}
- Scope: Local Docker lab only
- Objective: validate SOC detection pipeline from an offensive endpoint
EOF

    if [ "${INSTALL_METASPLOIT:-false}" = "true" ] && ! command -v msfconsole >/dev/null 2>&1; then
        echo "Installing Metasploit Framework. This can take several minutes..."
        curl -sSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o /tmp/msfinstall
        chmod 755 /tmp/msfinstall
        /tmp/msfinstall || true
    fi

    cat >/usr/local/bin/msf-lab-console <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$(date '+%b %e %H:%M:%S') metasploit-node metasploit-lab: action=msfconsole_launch detail=interactive_console_started" >> /var/log/metasploit-lab.log
if command -v msfconsole >/dev/null 2>&1; then
    exec msfconsole "$@"
fi
echo "msfconsole is not installed in this lightweight Docker profile."
echo "Set INSTALL_METASPLOIT=true before docker compose up if you need the full framework."
EOF
    chmod 755 /usr/local/bin/msf-lab-console

    cat >/usr/local/bin/metasploit-demo-generate-events.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "\$(date '+%b %e %H:%M:%S') metasploit-node metasploit-lab: action=module_launch detail=module=auxiliary/scanner/http/title target=pyme-demo-target outcome=simulated" >> "$msf_log"
echo "\$(date '+%b %e %H:%M:%S') metasploit-node metasploit-lab: action=workspace_update detail=workspace=${METASPLOIT_WORKSPACE_NAME:-customer_pyme_demo} note=engagement_note_updated" >> "$msf_log"
echo "\$(date '+%b %e %H:%M:%S') metasploit-node metasploit-lab: action=session_event detail=session=reverse_tcp handler=demo-lab outcome=simulated" >> "$msf_log"
echo "engagement_note_updated=\$(date -Is)" >> "/opt/metasploit-lab/workspaces/${METASPLOIT_WORKSPACE_NAME:-customer_pyme_demo}/engagement-notes.md"
echo "Metasploit demo events generated."
EOF
    chmod +x /usr/local/bin/metasploit-demo-generate-events.sh
}

configure_metasploit_node() {
    append_ossec_config "LOCAL_DOCKER_METASPLOIT" '<ossec_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/metasploit-lab.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    <directories realtime="yes" report_changes="yes">/opt/metasploit-lab</directories>
    <directories realtime="yes" report_changes="yes">/opt/wazuh-module-demo</directories>
  </syscheck>
</ossec_config>'
}

provision_edge_gateway() {
    local gateway_log="/var/log/gateway-lab.log"
    ensure_log "$gateway_log"
    mkdir -p /opt/gateway-lab /etc/wireguard

    if [ ! -f /opt/gateway-lab/sample-peer.conf ]; then
        local server_private_key server_public_key client_private_key client_public_key
        server_private_key="$(wg genkey)"
        server_public_key="$(printf '%s' "$server_private_key" | wg pubkey)"
        client_private_key="$(wg genkey)"
        client_public_key="$(printf '%s' "$client_private_key" | wg pubkey)"

        cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.20.0.1/24
ListenPort = ${WIREGUARD_PORT:-51820}
PrivateKey = $server_private_key

[Peer]
PublicKey = $client_public_key
AllowedIPs = 10.20.0.2/32
EOF
        cat >/opt/gateway-lab/sample-peer.conf <<EOF
[Interface]
PrivateKey = $client_private_key
Address = 10.20.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = $server_public_key
AllowedIPs = 172.30.50.0/24
Endpoint = edge-gateway:${WIREGUARD_PORT:-51820}
PersistentKeepalive = 25
EOF
    fi

    cat >/usr/local/bin/gateway-demo-generate-events.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "\$(date '+%b %e %H:%M:%S') edge-gateway gateway-lab: action=vpn_peer_connected detail=peer=customer-laptop assigned_ip=10.20.0.2 outcome=simulated" >> "$gateway_log"
echo "\$(date '+%b %e %H:%M:%S') edge-gateway gateway-lab: action=firewall_drop detail=src=198.51.100.25 dst=172.30.50.2 dport=1514 proto=tcp outcome=blocked" >> "$gateway_log"
echo "\$(date '+%b %e %H:%M:%S') edge-gateway gateway-lab: action=config_change detail=file=/etc/wireguard/wg0.conf outcome=simulated" >> "$gateway_log"
echo "# last-reviewed=\$(date -Is)" >> /opt/gateway-lab/sample-peer.conf
echo "Gateway demo events generated."
EOF
    chmod +x /usr/local/bin/gateway-demo-generate-events.sh
}

configure_edge_gateway() {
    append_ossec_config "LOCAL_DOCKER_EDGE_GATEWAY" '<ossec_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/gateway-lab.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    <directories realtime="yes" report_changes="yes">/etc/wireguard</directories>
    <directories realtime="yes" report_changes="yes">/opt/gateway-lab</directories>
    <directories realtime="yes" report_changes="yes">/opt/wazuh-module-demo</directories>
  </syscheck>
</ossec_config>'
}

provision_db_server() {
    local db_log="/var/log/db-lab.log"
    ensure_log "$db_log"
    mkdir -p /opt/db-lab /run/mysqld
    chown -R mysql:mysql /run/mysqld /var/lib/mysql || true
    mysqld_safe --skip-networking=0 --bind-address=0.0.0.0 &

    for attempt in $(seq 1 60); do
        if mysqladmin ping --silent >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done

    mysql <<EOF || true
CREATE DATABASE IF NOT EXISTS ${DB_NAME:-customer360};
USE ${DB_NAME:-customer360};
CREATE TABLE IF NOT EXISTS customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(180) NOT NULL,
    tier VARCHAR(32) NOT NULL
);
CREATE TABLE IF NOT EXISTS audit_events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    event_name VARCHAR(120) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO audit_events (event_name) VALUES ('db_lab_initialized');
EOF

    cat >/opt/db-lab/backup-manifest.txt <<EOF
backup_scope=${DB_NAME:-customer360}
created_at=$(date -Is)
retention_days=30
EOF

    cat >/usr/local/bin/db-demo-generate-events.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "\$(date '+%b %e %H:%M:%S') db-server db-lab: action=failed_login detail=user=reporter src=172.30.50.10 outcome=simulated" >> "$db_log"
echo "\$(date '+%b %e %H:%M:%S') db-server db-lab: action=schema_change detail=db=${DB_NAME:-customer360} table=audit_events operation=alter outcome=simulated" >> "$db_log"
echo "\$(date '+%b %e %H:%M:%S') db-server db-lab: action=sensitive_query detail=db=${DB_NAME:-customer360} table=customers field=email rows=3 outcome=simulated" >> "$db_log"
echo "backup_manifest_reviewed=\$(date -Is)" >> /opt/db-lab/backup-manifest.txt
echo "Database demo events generated."
EOF
    chmod +x /usr/local/bin/db-demo-generate-events.sh
}

configure_db_server() {
    append_ossec_config "LOCAL_DOCKER_DB_SERVER" '<ossec_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/db-lab.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    <directories realtime="yes" report_changes="yes">/etc/mysql</directories>
    <directories realtime="yes" report_changes="yes">/opt/db-lab</directories>
    <directories realtime="yes" report_changes="yes">/opt/wazuh-module-demo</directories>
  </syscheck>
</ossec_config>'
}

provision_docker_host() {
    local docker_log="/var/log/docker-lab.log"
    ensure_log "$docker_log"
    mkdir -p /opt/docker-lab/customer-portal/site /opt/docker-lab/queue-cache /etc/docker
    cat >/opt/docker-lab/customer-portal/site/index.html <<'EOF'
<!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>Customer Portal</title></head>
<body><h1>Customer Portal Demo</h1><p>Servicio demo en docker-host local.</p></body></html>
EOF
    cat >/etc/docker/daemon.json <<'EOF'
{
  "live-restore": true,
  "log-driver": "json-file"
}
EOF
    cat >/usr/local/bin/docker-demo-generate-events.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "\$(date '+%b %e %H:%M:%S') docker-host docker-lab: action=container_restart detail=container=customer-portal outcome=simulated" >> "$docker_log"
echo "\$(date '+%b %e %H:%M:%S') docker-host docker-lab: action=image_pull detail=image=alpine:latest outcome=simulated" >> "$docker_log"
echo "\$(date '+%b %e %H:%M:%S') docker-host docker-lab: action=config_drift detail=file=/opt/docker-lab/customer-portal/site/index.html outcome=simulated" >> "$docker_log"
echo "<p>Config drift marker: \$(date -Is)</p>" >> /opt/docker-lab/customer-portal/site/index.html
echo "Docker host demo events generated."
EOF
    chmod +x /usr/local/bin/docker-demo-generate-events.sh
    python3 -m http.server "${DOCKER_DEMO_PORT:-8081}" --directory /opt/docker-lab/customer-portal/site &
}

configure_docker_host() {
    append_ossec_config "LOCAL_DOCKER_DOCKER_HOST" '<ossec_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/docker-lab.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    <directories realtime="yes" report_changes="yes">/opt/docker-lab</directories>
    <directories realtime="yes" report_changes="yes">/etc/docker</directories>
    <directories realtime="yes" report_changes="yes">/opt/wazuh-module-demo</directories>
  </syscheck>
</ossec_config>'
}

provision_linux_ui_workstation() {
    local lab_user="${LINUX_UI_USER:-esquivel}"
    local sensitive_dir="${LINUX_UI_SENSITIVE_DIR:-/home/$lab_user/Confidencial}"
    local password_file="/root/linux-ui-rdp-credentials.txt"

    if ! id "$lab_user" >/dev/null 2>&1; then
        useradd -m -s /bin/bash "$lab_user"
    fi

    if [ ! -f "$password_file" ]; then
        local lab_password
        lab_password="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)Aa1!"
        echo "$lab_user:$lab_password" | chpasswd
        cat >"$password_file" <<EOF
linux_ui_host=linux-ui-workstation
rdp_user=$lab_user
rdp_password=$lab_password
rdp_port=13389
sensitive_folder=$sensitive_dir
documents_shortcut=/home/$lab_user/Documents/Confidencial
EOF
        chmod 600 "$password_file"
    fi

    echo "xfce4-session" >"/home/$lab_user/.xsession"
    chown "$lab_user:$lab_user" "/home/$lab_user/.xsession"

    mkdir -p "$sensitive_dir" "/home/$lab_user/Documents" "/home/$lab_user/Documentos" "/home/$lab_user/Desktop" /run/xrdp
    chown root:"$lab_user" "$sensitive_dir"
    chmod 0770 "$sensitive_dir"
    if [ "$sensitive_dir" != "/Confidencial" ]; then
        if [ -d /Confidencial ] && [ ! -L /Confidencial ]; then
            cp -a /Confidencial/. "$sensitive_dir/" 2>/dev/null || true
            rm -rf /Confidencial
        fi
        ln -sfn "$sensitive_dir" /Confidencial
    fi
    ln -sfn "$sensitive_dir" "/home/$lab_user/Documents/Confidencial"
    ln -sfn "$sensitive_dir" "/home/$lab_user/Documentos/Confidencial"
    ln -sfn "$sensitive_dir" "/home/$lab_user/Desktop/Confidencial"
    chown -R "$lab_user:$lab_user" "/home/$lab_user/Documents" "/home/$lab_user/Documentos" "/home/$lab_user/Desktop"

    cat >"$sensitive_dir/README-demo.txt" <<'EOF'
Carpeta sensible de demostracion.
Los cambios aqui generan la regla 100015.
Una rafaga de cambios genera la regla 100010.
EOF
    chown root:"$lab_user" "$sensitive_dir/README-demo.txt"
    chmod 0660 "$sensitive_dir/README-demo.txt"

    cat >/usr/local/bin/simulate-confidential-ransomware-burst.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
TARGET_DIR="${1:-${LINUX_UI_SENSITIVE_DIR:-/home/${LINUX_UI_USER:-esquivel}/Confidencial}}"
RUN_ID="$(date +%Y%m%d%H%M%S)"
mkdir -p "$TARGET_DIR"
for i in $(seq 1 6); do
    original="$TARGET_DIR/demo-sensitive-$RUN_ID-$i.txt"
    encrypted="$original.locked"
    printf 'customer_id=%03d\nstatus=confidential\n' "$i" > "$original"
    printf 'encrypted_at=%s\noriginal=%s\n' "$(date -Is)" "$original" > "$encrypted"
    rm -f "$original"
    sleep 0.5
done
find "$TARGET_DIR" -maxdepth 1 -type f -name '*.locked' -print
echo "Burst completed. Review rules 100015 and 100010."
EOF
    chmod +x /usr/local/bin/simulate-confidential-ransomware-burst.sh

    cat >/usr/local/bin/linux-ui-demo-auth-failure.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$(date '+%b %e %H:%M:%S') linux-ui-workstation sshd[53022]: Failed password for esquivel from 203.0.113.50 port 53022 ssh2" >> /var/log/auth.log
echo "$(date '+%b %e %H:%M:%S') linux-ui-workstation su: FAILED su for esquivel by root" >> /var/log/auth.log
echo "Generated controlled auth failures for user esquivel. Review rule 100020."
EOF
    chmod +x /usr/local/bin/linux-ui-demo-auth-failure.sh

    cat >/usr/local/bin/linux-ui-demo-portscan-log.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SRC="${1:-172.30.50.11}"
for port in 21 23 25 53 110 139; do
    echo "$(date '+%b %e %H:%M:%S') linux-ui-workstation kernel: wazuh-fw-drop: IN=eth0 OUT= MAC= SRC=$SRC DST=172.30.50.15 LEN=60 PROTO=TCP SPT=53000 DPT=$port SYN" >> /var/log/kern.log
done
echo "Generated controlled firewall-drop scan logs. Review rule 100030."
EOF
    chmod +x /usr/local/bin/linux-ui-demo-portscan-log.sh

    /etc/init.d/dbus start || true
    /usr/sbin/xrdp-sesman --nodaemon &
    /usr/sbin/xrdp --nodaemon &
}

configure_linux_ui_workstation() {
    local lab_user="${LINUX_UI_USER:-esquivel}"
    local sensitive_dir="${LINUX_UI_SENSITIVE_DIR:-/home/$lab_user/Confidencial}"

    append_ossec_config "LOCAL_DOCKER_LINUX_UI" '<ossec_config>
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
    <frequency>120</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    <auto_ignore frequency="10" timeframe="3600">no</auto_ignore>
    <directories realtime="yes" report_changes="yes" check_all="yes">'$sensitive_dir'</directories>
    <directories realtime="yes" report_changes="yes" check_all="yes">/opt/wazuh-module-demo</directories>
  </syscheck>
</ossec_config>'
}

run_initial_events() {
    local linux_ui_user="${LINUX_UI_USER:-esquivel}"
    local linux_ui_sensitive_dir="${LINUX_UI_SENSITIVE_DIR:-/home/$linux_ui_user/Confidencial}"

    /usr/local/bin/wazuh-demo-generate-module-events.sh || true

    case "$PROFILE" in
        pyme-demo-target) /usr/local/bin/pyme-demo-generate-events.sh || true ;;
        metasploit-node) /usr/local/bin/metasploit-demo-generate-events.sh || true ;;
        edge-gateway) /usr/local/bin/gateway-demo-generate-events.sh || true ;;
        db-server) /usr/local/bin/db-demo-generate-events.sh || true ;;
        docker-host) /usr/local/bin/docker-demo-generate-events.sh || true ;;
        linux-ui-workstation)
            mkdir -p "$linux_ui_sensitive_dir"
            echo "created_at=$(date -Is)" >>"$linux_ui_sensitive_dir/initial-access-review.txt"
            /usr/local/bin/linux-ui-demo-auth-failure.sh || true
            /usr/local/bin/linux-ui-demo-portscan-log.sh || true
            ;;
    esac
}

configure_common_logs

case "$PROFILE" in
    pyme-demo-target)
        provision_pyme_demo_target
        install_wazuh_agent
        configure_pyme_demo_target
        ;;
    metasploit-node)
        provision_metasploit_node
        install_wazuh_agent
        configure_metasploit_node
        ;;
    edge-gateway)
        provision_edge_gateway
        install_wazuh_agent
        configure_edge_gateway
        ;;
    db-server)
        provision_db_server
        install_wazuh_agent
        configure_db_server
        ;;
    docker-host)
        provision_docker_host
        install_wazuh_agent
        configure_docker_host
        ;;
    linux-ui-workstation)
        provision_linux_ui_workstation
        install_wazuh_agent
        configure_linux_ui_workstation
        ;;
    *)
        echo "Unknown ENDPOINT_PROFILE=$PROFILE"
        exit 1
        ;;
esac

provision_agent_module_demo
configure_common_wazuh_modules
configure_docker_listener_module

start_wazuh_agent
run_initial_events

echo "Endpoint $WAZUH_AGENT_NAME is ready."
touch /var/ossec/logs/ossec.log /var/log/apache2/access.log /var/log/apache2/error.log || true
tail -F "$STARTUP_LOG" /var/ossec/logs/ossec.log /var/log/auth.log /var/log/syslog /var/log/kern.log /var/log/wazuh-agent-modules-demo.log /var/log/cloud-gcp-demo.log 2>/dev/null
