#!/usr/bin/env bash

set -euo pipefail

AGENT_NAME="$(hostname)"
DOCKER_LOG="/var/log/docker-lab.log"
DOCKER_NATIVE_LOG="/var/log/docker-native-demo.json"
CLOUD_LOG="/var/log/cloud-gcp-demo.log"
MARKER="WAZUH_DOCKER_CLOUD_SECURITY_MODULES"
NATIVE_MARKER="WAZUH_DOCKER_NATIVE_JSON_DEMO"

touch "$DOCKER_LOG" "$DOCKER_NATIVE_LOG" "$CLOUD_LOG"
chown root:adm "$DOCKER_LOG" "$DOCKER_NATIVE_LOG" "$CLOUD_LOG" 2>/dev/null || true
chmod 664 "$DOCKER_LOG" "$DOCKER_NATIVE_LOG" "$CLOUD_LOG"

if ! grep -q "$MARKER" /var/ossec/etc/ossec.conf; then
    cat >>/var/ossec/etc/ossec.conf <<'EOF'
<!-- WAZUH_DOCKER_CLOUD_SECURITY_MODULES -->
<ossec_config>
  <labels>
    <label key="lab">wazuh-security-mvp</label>
    <label key="module_catalog">container-cloud-security</label>
  </labels>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/cloud-gcp-demo.log</location>
  </localfile>

  <wodle name="docker-listener">
    <disabled>no</disabled>
    <interval>2m</interval>
    <attempts>5</attempts>
    <run_on_start>yes</run_on_start>
  </wodle>
</ossec_config>
EOF
fi

if ! grep -q "$NATIVE_MARKER" /var/ossec/etc/ossec.conf; then
    cat >>/var/ossec/etc/ossec.conf <<'EOF'
<!-- WAZUH_DOCKER_NATIVE_JSON_DEMO -->
<ossec_config>
  <localfile>
    <log_format>json</log_format>
    <location>/var/log/docker-native-demo.json</location>
  </localfile>
</ossec_config>
EOF
fi

cat >/usr/local/bin/docker-demo-generate-events.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail

if command -v docker >/dev/null 2>&1; then
    docker restart customer-portal >/dev/null 2>&1 || true
    docker pull alpine:latest >/dev/null 2>&1 || true
fi

echo "\$(date '+%b %e %H:%M:%S') $AGENT_NAME docker-lab: action=container_restart detail=container=customer-portal outcome=simulated" >> "$DOCKER_LOG"
echo "\$(date '+%b %e %H:%M:%S') $AGENT_NAME docker-lab: action=image_pull detail=image=alpine:latest outcome=simulated" >> "$DOCKER_LOG"
echo "\$(date '+%b %e %H:%M:%S') $AGENT_NAME docker-lab: action=config_drift detail=file=/opt/docker-lab/customer-portal/site/index.html outcome=simulated" >> "$DOCKER_LOG"
echo "\$(date '+%b %e %H:%M:%S') $AGENT_NAME wazuh-module-demo: module=container_security action=docker_listener_expected detail=profile=docker-host socket=/var/run/docker.sock outcome=enabled" >> "$DOCKER_LOG"
logger -t docker-lab "action=container_restart detail=container=customer-portal outcome=simulated"
logger -t docker-lab "action=image_pull detail=image=alpine:latest outcome=simulated"
logger -t docker-lab "action=config_drift detail=file=/opt/docker-lab/customer-portal/site/index.html outcome=simulated"
logger -t wazuh-module-demo "module=container_security action=docker_listener_expected detail=profile=docker-host socket=/var/run/docker.sock outcome=enabled"

event_time="\$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
cat >> "$DOCKER_NATIVE_LOG" <<JSON
{"integration":"docker","docker":{"status":"restart","id":"customer-portal","from":"nginx:alpine","Type":"container","Action":"restart","Actor":{"ID":"customer-portal","Attributes":{"name":"customer-portal","image":"nginx:alpine"}}},"time":"\$event_time"}
{"integration":"docker","docker":{"status":"pull","id":"alpine:latest","from":"alpine:latest","Type":"image","Action":"pull","Actor":{"ID":"alpine:latest","Attributes":{"name":"alpine:latest","image":"alpine:latest"}}},"time":"\$event_time"}
{"integration":"docker","docker":{"status":"start","id":"queue-cache","from":"redis:7-alpine","Type":"container","Action":"start","Actor":{"ID":"queue-cache","Attributes":{"name":"queue-cache","image":"redis:7-alpine"}}},"time":"\$event_time"}
JSON

mkdir -p /opt/docker-lab/customer-portal/site
echo "<p>Config drift marker: \$(date -Is)</p>" >> /opt/docker-lab/customer-portal/site/index.html
EOF
chmod +x /usr/local/bin/docker-demo-generate-events.sh

cat >/usr/local/bin/cloud-security-demo-generate-events.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail

echo "\$(date '+%b %e %H:%M:%S') $AGENT_NAME gcp-demo: module=cloud_security action=iam_policy_change detail=project=wazuh-iac-on-gcp resource=demo-service-account outcome=simulated" >> "$CLOUD_LOG"
echo "\$(date '+%b %e %H:%M:%S') $AGENT_NAME gcp-demo: module=cloud_security action=compute_instance_stop detail=project=wazuh-iac-on-gcp instance=legacy-demo-vm outcome=simulated" >> "$CLOUD_LOG"
logger -t gcp-demo "module=cloud_security action=iam_policy_change detail=project=wazuh-iac-on-gcp resource=demo-service-account outcome=simulated"
logger -t gcp-demo "module=cloud_security action=compute_instance_stop detail=project=wazuh-iac-on-gcp instance=legacy-demo-vm outcome=simulated"
EOF
chmod +x /usr/local/bin/cloud-security-demo-generate-events.sh

cat >/usr/local/bin/docker-cloud-security-demo.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[docker-cloud-demo] Generando eventos Docker nativos y Cloud Security..."
/usr/local/bin/docker-demo-generate-events.sh || true
/usr/local/bin/cloud-security-demo-generate-events.sh || true
echo "[docker-cloud-demo] Ultimos eventos Docker nativos escritos en /var/log/docker-native-demo.json:"
tail -n 3 /var/log/docker-native-demo.json || true
echo "[docker-cloud-demo] Busca en Wazuh: agent.id: 017 and rule.id: (87903 or 87909 or 87932)"
echo "[docker-cloud-demo] Reglas esperadas: 87909 restart, 87932 pull, 87903 start."
EOF
chmod +x /usr/local/bin/docker-cloud-security-demo.sh

systemctl restart wazuh-agent
/usr/local/bin/docker-cloud-security-demo.sh

echo "Docker and Cloud Security module demo configured on $(hostname)."
