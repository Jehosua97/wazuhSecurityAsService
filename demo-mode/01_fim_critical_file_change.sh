#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/demo_common.sh
. "$SCRIPT_DIR/lib/demo_common.sh"

RID="$(run_id)"
log_info "Escenario 01: cambio seguro en archivo critico monitoreado por FIM."

remote_script='
set -euo pipefail
target="/Confidencial/demo-mode-critical-file.txt"
mkdir -p /Confidencial
if [ ! -f "$target" ]; then
    cat >"$target" <<EOF
cliente=Demo Corp
clasificacion=confidencial
proposito=archivo controlado para FIM
EOF
fi
printf "demo_mode_change=%s\n" "$(date -Is)" >> "$target"
echo "$(date "+%b %e %H:%M:%S") linux-ui-workstation pyme-demo: action=fim_critical_file_change file=$target outcome=completed" >> /var/log/syslog
printf "Archivo FIM modificado: %s\n" "$target"
'

compose_exec "linux-ui-workstation" "$remote_script"

write_evidence_file \
    "${RID}_01_fim_critical_file_change.md" \
    "Cambio en archivo critico monitoreado por FIM" \
    "Modificacion controlada en /Confidencial para disparar FIM." \
    'agent.name: "linux-ui-workstation" and (rule.id: 100015 or rule.id: 100010 or full_log: "fim_critical_file_change")' \
    'bash demo-mode/reset_demo.sh'

log_info "Escenario 01 completado."

