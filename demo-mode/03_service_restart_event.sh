#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/demo_common.sh
. "$SCRIPT_DIR/lib/demo_common.sh"

RID="$(run_id)"
log_info "Escenario 03: evento controlado de servicio detenido/reiniciado."

remote_script='
set -euo pipefail
state_file="/opt/pyme-compliance/evidence/demo-mode-service-state.txt"
mkdir -p "$(dirname "$state_file")"
{
    echo "service=customer-web"
    echo "event=stopped_then_restarted"
    echo "timestamp=$(date -Is)"
    echo "origin=demo-mode"
} > "$state_file"
echo "$(date "+%b %e %H:%M:%S") pyme-demo-target pyme-demo: action=service_stopped service=customer-web outcome=simulated" >> /var/log/syslog
sleep 1
echo "$(date "+%b %e %H:%M:%S") pyme-demo-target pyme-demo: action=service_restarted service=customer-web outcome=simulated" >> /var/log/syslog
printf "Evento de servicio simulado y documentado: %s\n" "$state_file"
'

compose_exec "pyme-demo-target" "$remote_script"

write_evidence_file \
    "${RID}_03_service_restart_event.md" \
    "Evento de servicio detenido y reiniciado" \
    "Simulacion no disruptiva de un servicio critico detenido y reiniciado." \
    'agent.name: "pyme-demo-target" and (rule.id: 100111 or rule.id: 100130 or full_log: "service_restarted" or full_log: "service_stopped")' \
    'bash demo-mode/reset_demo.sh'

log_info "Escenario 03 completado."

