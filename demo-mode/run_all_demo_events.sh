#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/demo_common.sh
. "$SCRIPT_DIR/lib/demo_common.sh"

RID="$(run_id)"
SUMMARY_FILE="$EVIDENCE_DIR/${RID}_run_all_summary.md"

log_info "Ejecutando todos los eventos demo-mode."

bash "$SCRIPT_DIR/01_fim_critical_file_change.sh"
sleep 2
bash "$SCRIPT_DIR/02_permission_change.sh"
sleep 2
bash "$SCRIPT_DIR/03_service_restart_event.sh"
sleep 2
bash "$SCRIPT_DIR/04_container_lifecycle_event.sh"
sleep 2
bash "$SCRIPT_DIR/05_anomalous_logs.sh"
sleep 2
bash "$SCRIPT_DIR/06_generate_report_evidence.sh"

cat >"$SUMMARY_FILE" <<EOF
# Resumen run_all demo-mode

- Fecha UTC: $(timestamp_utc)
- Run ID: $RID
- Resultado: scripts ejecutados correctamente

## Scripts ejecutados

1. 01_fim_critical_file_change.sh
2. 02_permission_change.sh
3. 03_service_restart_event.sh
4. 04_container_lifecycle_event.sh
5. 05_anomalous_logs.sh
6. 06_generate_report_evidence.sh

## Consulta rapida en Wazuh

\`\`\`text
agent.name: ("pyme-demo-target" or "linux-ui-workstation" or "docker-host") and rule.level >= 6
\`\`\`

## Reset

\`\`\`bash
bash demo-mode/reset_demo.sh
\`\`\`
EOF

log_info "Resumen creado: $SUMMARY_FILE"
log_info "Todos los eventos demo-mode fueron ejecutados."
