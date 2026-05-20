#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/demo_common.sh
. "$SCRIPT_DIR/lib/demo_common.sh"

RID="$(run_id)"
log_info "Escenario 02: modificacion segura de permisos en archivo de prueba."

remote_script='
set -euo pipefail
target="/opt/pyme-compliance/customer-data/demo-mode-permission-test.txt"
mkdir -p "$(dirname "$target")"
cat >"$target" <<EOF
dataset=demo
owner=security-team
purpose=permission-change-test
EOF
chmod 0640 "$target"
chmod 0666 "$target"
echo "$(date "+%b %e %H:%M:%S") pyme-demo-target pyme-demo: action=permission_change file=$target mode=0666 outcome=completed" >> /var/log/syslog
printf "Permisos modificados de forma controlada: %s -> 0666\n" "$target"
'

compose_exec "pyme-demo-target" "$remote_script"

write_evidence_file \
    "${RID}_02_permission_change.md" \
    "Modificacion de permisos en archivo de prueba" \
    "Cambio controlado de permisos en /opt/pyme-compliance para mostrar FIM y riesgo de exposicion." \
    'agent.name: "pyme-demo-target" and (rule.id: 100130 or rule.id: 100131 or rule.id: 100111 or full_log: "permission_change")' \
    'bash demo-mode/reset_demo.sh'

log_info "Escenario 02 completado."

