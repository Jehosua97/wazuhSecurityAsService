#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/demo_common.sh
. "$SCRIPT_DIR/lib/demo_common.sh"

RID="$(run_id)"
RESET_FILE="$EVIDENCE_DIR/${RID}_reset_demo.md"

log_info "Revirtiendo cambios demo-mode seguros."

compose_exec_optional "linux-ui-workstation" '
set -euo pipefail
rm -f /Confidencial/demo-mode-critical-file.txt
echo "$(date "+%b %e %H:%M:%S") linux-ui-workstation pyme-demo: action=demo_reset scope=linux-ui-workstation outcome=completed" >> /var/log/syslog
'

compose_exec_optional "pyme-demo-target" '
set -euo pipefail
rm -f /opt/pyme-compliance/customer-data/demo-mode-permission-test.txt
rm -f /opt/pyme-compliance/evidence/demo-mode-service-state.txt
rm -f /opt/pyme-compliance/evidence/demo-mode-report-evidence.md
chmod 0660 /opt/pyme-compliance/customer-data/clientes-demo.csv 2>/dev/null || true
echo "$(date "+%b %e %H:%M:%S") pyme-demo-target pyme-demo: action=demo_reset scope=pyme-demo-target outcome=completed" >> /var/log/syslog
'

compose_exec_optional "docker-host" '
set -euo pipefail
rm -f /opt/docker-lab/customer-portal/site/demo-container-state.txt
echo "$(date "+%b %e %H:%M:%S") docker-host docker-lab: action=demo_reset detail=container_demo_state_removed outcome=completed" >> /var/log/docker-lab.log
'

cat >"$RESET_FILE" <<EOF
# Reset demo-mode

- Fecha UTC: $(timestamp_utc)
- Run ID: $RID
- Accion: eliminados artefactos temporales de demo y restaurados permisos de prueba.

## Nota

Los logs no se truncaron. Se conservan como evidencia historica para Wazuh y reportes.
EOF

log_info "Reset completado. Evidencia local: $RESET_FILE"

