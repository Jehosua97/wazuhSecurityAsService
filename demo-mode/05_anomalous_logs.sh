#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/demo_common.sh
. "$SCRIPT_DIR/lib/demo_common.sh"

RID="$(run_id)"
log_info "Escenario 05: generacion de logs anomalos no ofensivos."

remote_script='
set -euo pipefail
access_log="/var/log/apache2/access.log"
panel_log="/var/log/pyme-attack-panel.log"
for i in 1 2 3 4 5; do
    echo "198.51.100.$i - - [$(date "+%d/%b/%Y:%H:%M:%S %z")] \"GET /healthcheck?node=$i HTTP/1.1\" 503 128" >> "$access_log"
done
echo "$(date "+%b %e %H:%M:%S") pyme-demo-target pyme-attack-panel: action=anomalous_log_burst outcome=completed detail=non_offensive_healthcheck_503_spike count=5" >> "$panel_log"
printf "Logs anomalos no ofensivos agregados a %s y %s\n" "$access_log" "$panel_log"
'

compose_exec "pyme-demo-target" "$remote_script"

write_evidence_file \
    "${RID}_05_anomalous_logs.md" \
    "Logs anomalos no ofensivos" \
    "Rafaga controlada de errores 503 en healthcheck para mostrar observabilidad sin ataque real." \
    'agent.name: "pyme-demo-target" and (rule.id: 100140 or full_log: "anomalous_log_burst" or full_log: "healthcheck")' \
    'No requiere rollback. Los logs se conservan como evidencia de demo.'

log_info "Escenario 05 completado."

