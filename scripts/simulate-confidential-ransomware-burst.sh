#!/usr/bin/env bash

set -euo pipefail

TARGET_DIR="${1:-${SENSITIVE_DIR:-/home/esquivel/Confidencial}}"
RUN_ID="$(date +%Y%m%d%H%M%S)"

mkdir -p "$TARGET_DIR"

echo "Generating a controlled ransomware-like FIM burst in $TARGET_DIR"
echo "Rule 100010 expects at least 4 FIM events in 10 seconds."

for i in $(seq 1 6); do
    original="$TARGET_DIR/demo-sensitive-$RUN_ID-$i.txt"
    encrypted="$original.locked"

    printf 'customer_id=%03d\nstatus=confidential\n' "$i" > "$original"
    printf 'encrypted_at=%s\noriginal=%s\n' "$(date -Is)" "$original" > "$encrypted"
    rm -f "$original"

    sleep 0.5
done

find "$TARGET_DIR" -maxdepth 1 -type f -name '*.locked' -print
echo "Burst completed. Review Wazuh alerts for rules 100015 and 100010."
