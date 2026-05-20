#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/demo_common.sh
. "$SCRIPT_DIR/lib/demo_common.sh"

RID="$(run_id)"
log_info "Escenario 04: evento controlado de contenedor detenido/reiniciado."

remote_script='
set -euo pipefail
log="/var/log/docker-lab.log"
state_file="/opt/docker-lab/customer-portal/site/demo-container-state.txt"
mkdir -p "$(dirname "$state_file")"
{
    echo "container=customer-portal"
    echo "event=stopped_then_restarted"
    echo "timestamp=$(date -Is)"
    echo "origin=demo-mode"
} > "$state_file"
echo "$(date "+%b %e %H:%M:%S") docker-host docker-lab: action=container_stop detail=container=customer-portal outcome=simulated" >> "$log"
sleep 1
echo "$(date "+%b %e %H:%M:%S") docker-host docker-lab: action=container_restart detail=container=customer-portal outcome=simulated" >> "$log"
printf "Evento de contenedor simulado y documentado: %s\n" "$state_file"
'

compose_exec "docker-host" "$remote_script"

write_evidence_file \
    "${RID}_04_container_lifecycle_event.md" \
    "Evento de contenedor detenido y reiniciado" \
    "Simulacion no disruptiva de ciclo de vida de contenedor en docker-host." \
    'agent.name: "docker-host" and (rule.id: 100190 or rule.id: 100191 or full_log: "container_stop" or full_log: "container_restart")' \
    'bash demo-mode/reset_demo.sh'

log_info "Escenario 04 completado."

