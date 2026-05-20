#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/demo_common.sh
. "$SCRIPT_DIR/lib/demo_common.sh"

RID="$(run_id)"
REPORT_FILE="$EVIDENCE_DIR/${RID}_06_report_evidence_bundle.md"

log_info "Escenario 06: generacion de evidencia para reporte."

remote_script='
set -euo pipefail
target="/opt/pyme-compliance/evidence/demo-mode-report-evidence.md"
mkdir -p "$(dirname "$target")"
cat >"$target" <<EOF
# Evidencia demo-mode

- Generado: $(date -Is)
- Proposito: evidencia controlada para reporte ejecutivo y tecnico.
- Datos reales: no
- Ambiente: laboratorio autorizado

## Eventos incluidos

- Cambio FIM controlado
- Cambio de permisos controlado
- Servicio detenido/reiniciado simulado
- Contenedor detenido/reiniciado simulado
- Logs anomalos no ofensivos
EOF
echo "$(date "+%b %e %H:%M:%S") pyme-demo-target pyme-demo: action=report_evidence_generated file=$target outcome=completed" >> /var/log/syslog
printf "Evidencia remota generada: %s\n" "$target"
'

compose_exec "pyme-demo-target" "$remote_script"

{
    echo "# Evidencia para reporte demo-mode"
    echo
    echo "- Fecha UTC: $(timestamp_utc)"
    echo "- Run ID: $RID"
    echo "- Ambiente: laboratorio local Docker + Wazuh en GCP"
    echo "- Datos reales: no"
    echo
    echo "## Estado de contenedores"
    echo
    echo '```text'
    compose ps || true
    echo '```'
    echo
    echo "## Consultas sugeridas en Wazuh"
    echo
    echo '```text'
    echo 'rule.groups: demo or rule.groups: evidence or rule.groups: soc_signal'
    echo 'agent.name: ("pyme-demo-target" or "linux-ui-workstation" or "docker-host")'
    echo 'rule.id: (100015 or 100111 or 100130 or 100131 or 100140 or 100190 or 100191)'
    echo '```'
    echo
    echo "## Evidencia esperada"
    echo
    echo "- Alertas FIM sobre /Confidencial."
    echo "- Alertas FIM sobre /opt/pyme-compliance."
    echo "- Evento docker-lab de contenedor reiniciado."
    echo "- Evento pyme-demo para reporte ejecutivo."
    echo "- Logs no ofensivos de error 503 en healthcheck."
} >"$REPORT_FILE"

log_info "Evidencia local creada: $REPORT_FILE"
log_info "Escenario 06 completado."

