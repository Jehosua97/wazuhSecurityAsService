#!/usr/bin/env bash
set -euo pipefail

EVIDENCE_DIR="/opt/wazuh-module-demo/evidence"
MODULE_LOG="/var/log/wazuh-agent-modules-demo.log"
mkdir -p "$EVIDENCE_DIR" "$(dirname "$MODULE_LOG")"

payload="$(cat || true)"
stamp="$(date -Is)"
evidence_file="$EVIDENCE_DIR/active-response-$stamp.json"

cat >"$evidence_file" <<JSON
{
  "timestamp": "$stamp",
  "action": "module-demo-response",
  "mode": "evidence-only",
  "payload": $(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
}
JSON

printf '%s %s wazuh-module-demo: module=active_response action=evidence_collected detail=file=%s\n' "$(date '+%b %e %H:%M:%S')" "$(hostname)" "$evidence_file" >> "$MODULE_LOG"
exit 0
