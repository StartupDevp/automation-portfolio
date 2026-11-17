#!/bin/bash
# check_versions.sh - เก็บข้อมูลจากทุกโหนดแบบขนาน (ไม่ต้องใช้ Ansible)
# วิธีใช้:  ./check_versions.sh [ไฟล์รายชื่อโหนด]      (ค่าเริ่มต้น hosts.txt)
# ปรับค่าได้ผ่านตัวแปร:  SSH_USER=gsops PARALLEL=16 ./check_versions.sh hosts.txt

set -u
HOST_LIST="${1:-hosts.txt}"
export SSH_USER="${SSH_USER:-gsops}"
PARALLEL="${PARALLEL:-16}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export COLLECTOR="$SCRIPT_DIR/collect_node.sh"
STAMP="$(date +%Y%m%d_%H%M%S)"
export WORKDIR="$PWD/audit_$STAMP"
OUTPUT_FILE="$PWD/version_audit_$STAMP.csv"

[ -f "$HOST_LIST" ] || { echo "ไม่พบไฟล์ $HOST_LIST"; exit 1; }
[ -f "$COLLECTOR" ] || { echo "ไม่พบ $COLLECTOR"; exit 1; }
mkdir -p "$WORKDIR/raw" "$WORKDIR/err"

check_node() {
    local host=$1 out rc
    # ส่ง collect_node.sh ผ่าน stdin ไปรันด้วย sudo บนโหนดปลายทาง (ไม่ต้องคัดลอกไฟล์ไปไว้ที่โหนด)
    out=$(timeout 180 ssh -o BatchMode=yes -o ConnectTimeout=8 \
              -o StrictHostKeyChecking=accept-new \
              "${SSH_USER}@${host}" 'sudo -n bash -s' < "$COLLECTOR" 2> "$WORKDIR/err/$host.txt")
    rc=$?
    if [ $rc -eq 0 ] && [ -n "$out" ]; then
        printf '%s\n' "$out" > "$WORKDIR/raw/$host.csv"
        echo "[ OK ] $host"
    else
        echo "$host (exit=$rc)" > "$WORKDIR/err/$host.failed"
        echo "[FAIL] $host (exit=$rc) -> ดู $WORKDIR/err/$host.txt"
    fi
}
export -f check_node

grep -v '^[[:space:]]*#' "$HOST_LIST" | sed '/^[[:space:]]*$/d' | tr -d '\r' \
    | xargs -P "$PARALLEL" -I{} bash -c 'check_node "$1"' _ {}

"$COLLECTOR" --header > "$OUTPUT_FILE"
cat "$WORKDIR"/raw/*.csv 2>/dev/null | sort >> "$OUTPUT_FILE"

ok=$(ls "$WORKDIR"/raw 2>/dev/null | wc -l)
fail=$(ls "$WORKDIR"/err/*.failed 2>/dev/null | wc -l)
echo "-----------------------------------------"
echo "สำเร็จ: $ok โหนด | ล้มเหลว: $fail โหนด"
echo "รายงาน: $OUTPUT_FILE"
[ "$fail" -gt 0 ] && { echo "โหนดที่ล้มเหลว:"; cat "$WORKDIR"/err/*.failed; }
exit 0
