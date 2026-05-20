#!/usr/bin/env bash
set -euo pipefail

DEMO_MODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$DEMO_MODE_DIR/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$REPO_ROOT/docker-compose.endpoints.yml}"
DEMO_COMPOSE_PROJECT_NAME="${DEMO_COMPOSE_PROJECT_NAME:-wazuh-local-endpoints}"
EVIDENCE_DIR="${EVIDENCE_DIR:-$DEMO_MODE_DIR/evidence}"
LOG_DIR="${LOG_DIR:-$DEMO_MODE_DIR/logs}"
DEMO_LOG="$LOG_DIR/demo-mode.log"

mkdir -p "$EVIDENCE_DIR" "$LOG_DIR"

timestamp_utc() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

run_id() {
    date -u '+%Y%m%dT%H%M%SZ'
}

log_info() {
    local message="$1"
    printf '[%s] %s\n' "$(timestamp_utc)" "$message" | tee -a "$DEMO_LOG"
}

fail() {
    local message="$1"
    printf '[%s] ERROR: %s\n' "$(timestamp_utc)" "$message" | tee -a "$DEMO_LOG" >&2
    exit 1
}

require_tool() {
    local tool="$1"
    command -v "$tool" >/dev/null 2>&1 || fail "No encontre '$tool' en PATH."
}

compose() {
    require_tool docker
    [ -f "$COMPOSE_FILE" ] || fail "No existe el compose file: $COMPOSE_FILE"
    (
        cd "$REPO_ROOT"
        COMPOSE_PROJECT_NAME="$DEMO_COMPOSE_PROJECT_NAME" docker compose -f "$COMPOSE_FILE" "$@"
    )
}

service_is_running() {
    local service="$1"
    compose ps --status running --services 2>/dev/null | grep -Fxq "$service"
}

require_service_running() {
    local service="$1"
    if ! service_is_running "$service"; then
        fail "El servicio '$service' no esta corriendo. Ejecuta: ./scripts/local-docker-lab.ps1 -Scope Linux -Action up"
    fi
}

compose_exec() {
    local service="$1"
    local remote_script="$2"
    require_service_running "$service"
    compose exec -T "$service" bash -lc "$remote_script"
}

compose_exec_optional() {
    local service="$1"
    local remote_script="$2"
    if service_is_running "$service"; then
        compose exec -T "$service" bash -lc "$remote_script"
    else
        log_info "Skip: servicio '$service' no esta corriendo."
    fi
}

write_evidence_file() {
    local file_name="$1"
    local title="$2"
    local scenario="$3"
    local wazuh_query="$4"
    local rollback="$5"
    local file_path="$EVIDENCE_DIR/$file_name"

    cat >"$file_path" <<EOF
# $title

- Fecha UTC: $(timestamp_utc)
- Escenario: $scenario
- Compose project: $DEMO_COMPOSE_PROJECT_NAME
- Compose file: $COMPOSE_FILE

## Consulta sugerida en Wazuh

\`\`\`text
$wazuh_query
\`\`\`

## Rollback

\`\`\`bash
$rollback
\`\`\`

## Nota

Evidencia generada por demo-mode. No contiene datos reales de clientes.
EOF

    log_info "Evidencia local creada: $file_path"
}

