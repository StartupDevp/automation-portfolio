#!/bin/bash
# audit.sh - เครื่องมือเดียวสำหรับตรวจสอบเวอร์ชัน Driver/Firmware ของคลัสเตอร์ B300
#
#   ./audit.sh test <โหนด> [ไอพี-BMC]   ทดสอบ 1 เครื่อง (ทำก่อนเสมอ)
#   ./audit.sh all [hosts.txt] [bmc.txt] เก็บข้อมูลทุกเครื่อง
#
# ตัวแปรที่ปรับได้:  SSH_USER (ค่าเริ่มต้น gsops)  PARALLEL (ค่าเริ่มต้น 12)
#                   BMC_USER / BMC_PASS (ถ้าไม่ตั้ง จะถามตอนรัน)

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
export SSH_USER="${SSH_USER:-gsops}"
PARALLEL="${PARALLEL:-12}"
export SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new"

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

# ---------- ฟังก์ชันพื้นฐาน ----------
ask_bmc_cred() {
    if [ -z "${BMC_USER:-}" ] || [ -z "${BMC_PASS:-}" ]; then
        read -r -p "BMC username: " BMC_USER
        read -r -s -p "BMC password (พิมพ์แล้วไม่แสดงตัวอักษร): " BMC_PASS
        echo
    fi
    export BMC_USER BMC_PASS
}

bmc_ip_of() {   # bmc_ip_of <โหนด> <ไฟล์>
    [ -f "$2" ] && awk -v h="$1" '$1==h && $1 !~ /^#/ {print $2; exit}' "$2"
}

remote() {      # remote <โหนด> <สคริปต์> [อาร์กิวเมนต์...]  (ส่งสคริปต์ไปรันด้วย sudo ที่โหนด)
    local host=$1 script=$2
    shift 2
    # shellcheck disable=SC2086
    timeout 300 ssh $SSH_OPTS "${SSH_USER}@${host}" "sudo -n bash -s -- $*" < "$script"
}
export -f remote

# เก็บข้อมูล 1 โหนดลงโฟลเดอร์ $OUT  (summary + raw + bmc)
collect_one() { # collect_one <โหนด> <ไอพี BMC หรือว่าง>
    local host=$1 bmcip=${2:-} s=FAIL r=FAIL b=SKIP out
    mkdir -p "$OUT/raw/$host"
    out=$(remote "$host" "$SCRIPT_DIR/collect_node.sh" 2> "$OUT/err/$host.summary.txt")
    if [ $? -eq 0 ] && [ -n "$out" ]; then printf '%s\n' "$out" > "$OUT/csv/$host.csv"; s=OK; fi
    if remote "$host" "$SCRIPT_DIR/collect_raw.sh" > "$OUT/raw/$host/raw.txt" 2> "$OUT/err/$host.raw.txt"; then r=OK; fi
    if [ -n "$bmcip" ]; then
        b=FAIL
        if "$SCRIPT_DIR/collect_bmc.sh" "$bmcip" > "$OUT/bmc/$host.tsv" 2> "$OUT/err/$host.bmc.txt" && [ -s "$OUT/bmc/$host.tsv" ]; then b=OK; else rm -f "$OUT/bmc/$host.tsv"; fi
    fi
    echo "$host summary=$s raw=$r bmc=$b" > "$OUT/status/$host.txt"
    printf '%-22s summary=%-4s raw=%-4s bmc=%s\n' "$host" "$s" "$r" "$b"
}
export -f collect_one bmc_ip_of

job() { collect_one "$1" "$(bmc_ip_of "$1" "$BMC_FILE")"; }
export -f job

prepare_out() {
    export OUT="$1"
    mkdir -p "$OUT"/{csv,raw,bmc,err,status}
}

finalize() {
    "$SCRIPT_DIR/collect_node.sh" --header > "$OUT/summary.csv"
    cat "$OUT"/csv/*.csv 2>/dev/null | sort >> "$OUT/summary.csv"
    if ls "$OUT"/bmc/*.tsv >/dev/null 2>&1; then
        awk -F'\t' '
        FNR==1 { nf++; n=FILENAME; sub(".*/","",n); sub(/\.tsv$/,"",n); name[nf]=n }
        { if (!($1 in seen)) { seen[$1]=1; ids[++ni]=$1 } v[nf,$1]=$2 }
        END {
            printf "host"; for (i=1;i<=ni;i++) printf ",%s", ids[i]; print ""
            for (f=1;f<=nf;f++) { printf "%s", name[f]
                for (i=1;i<=ni;i++) { x=v[f,ids[i]]; if (x=="") x="N/A"; gsub(/,/,";",x); printf ",%s", x }
                print "" }
        }' "$OUT"/bmc/*.tsv > "$OUT/bmc_report.csv"
    fi
    {
        echo "######## สรุปเวอร์ชันจากระบบปฏิบัติการ (summary.csv) ########"
        "$SCRIPT_DIR/analyze.sh" "$OUT/summary.csv"
        if [ -f "$OUT/bmc_report.csv" ]; then
            echo; echo "######## เฟิร์มแวร์จาก BMC / Redfish (bmc_report.csv) ########"
            "$SCRIPT_DIR/analyze.sh" "$OUT/bmc_report.csv"
        fi
    } > "$OUT/analysis.txt"
}

# ---------- โหมด test ----------
preflight() {   # preflight <โหนด>
    local host=$1 out miss
    p() { printf '  [%s] %s\n' "$1" "$2"; }
    # shellcheck disable=SC2086
    if out=$(ssh $SSH_OPTS "${SSH_USER}@${host}" hostname 2>&1); then p PASS "SSH เข้าได้ (ชื่อเครื่อง: $out)"; else p FAIL "SSH เข้าไม่ได้: $out"; return 1; fi
    # shellcheck disable=SC2086
    if ssh $SSH_OPTS "${SSH_USER}@${host}" 'sudo -n true' 2>/dev/null; then p PASS "sudo แบบไม่ถามรหัส ใช้ได้"; else p FAIL "sudo ต้องใช้รหัสผ่าน (ดูขั้นตอนตั้งค่า sudo)"; return 1; fi
    # shellcheck disable=SC2086
    miss=$(ssh $SSH_OPTS "${SSH_USER}@${host}" 'sudo -n bash -c '"'"'export PATH=$PATH:/usr/sbin:/sbin:/opt/mellanox/doca/tools; for c in lspci ofed_info mstflint nvidia-smi ipmitool dmidecode; do command -v $c >/dev/null 2>&1 || printf "%s " $c; done'"'"'' 2>/dev/null)
    if [ -z "$miss" ]; then p PASS "เครื่องมือบนโหนดครบ (lspci ofed_info mstflint nvidia-smi ipmitool dmidecode)"; else p WARN "ไม่พบเครื่องมือบนโหนด: $miss (ข้อมูลส่วนนั้นจะเป็น N/A)"; fi
    return 0
}

cmd_test() {
    local host=${1:-} bmcip=${2:-}
    [ -n "$host" ] || usage
    [ -n "$bmcip" ] || bmcip=$(bmc_ip_of "$host" "${BMC_FILE:-bmc.txt}")
    echo "=== ทดสอบโหนด: $host ${bmcip:+(BMC: $bmcip)} ==="
    echo "--- 1) ตรวจความพร้อม ---"
    preflight "$host" || { echo "หยุด: แก้ข้อ FAIL ก่อน แล้วรันใหม่"; exit 2; }
    if [ -n "$bmcip" ]; then
        local code
        code=$(curl -sk -m 8 -o /dev/null -w '%{http_code}' "https://${bmcip}/redfish/v1/" 2>/dev/null)
        if [ "$code" = "200" ] || [ "$code" = "401" ]; then printf '  [PASS] BMC %s ตอบกลับ Redfish (HTTP %s)\n' "$bmcip" "$code"; else printf '  [FAIL] BMC %s ไม่ตอบ Redfish (HTTP %s) - ตรวจเครือข่ายจัดการ/IP\n' "$bmcip" "${code:-none}"; fi
        ask_bmc_cred
    else
        echo "  [WARN] ไม่ได้ระบุ BMC -> ข้ามการเก็บข้อมูลจาก BMC (ระบุได้: ./audit.sh test $host <ไอพี-BMC>)"
    fi
    prepare_out "results_test_${host}_$(date +%Y%m%d_%H%M%S)"
    echo "--- 2) เก็บข้อมูล (อาจใช้เวลา 1-3 นาที) ---"
    collect_one "$host" "$bmcip"
    finalize
    echo "--- 3) ผลสรุปของโหนดนี้ ---"
    awk -F, 'NR==1 {for(i=1;i<=NF;i++) h[i]=$i; next} {for(i=1;i<=NF;i++) printf "  %-16s : %s\n", h[i], $i}' "$OUT/summary.csv"
    local na
    na=$(awk -F, 'NR>1 {for(i=1;i<=NF;i++) if($i=="N/A") printf "%s ", h[i]} NR==1 {for(i=1;i<=NF;i++) h[i]=$i}' "$OUT/summary.csv")
    [ -n "$na" ] && echo "  >> คอลัมน์ที่เก็บไม่ได้ (N/A): $na" || echo "  >> ไม่มีคอลัมน์ N/A"
    if [ -s "$OUT/bmc/$host.tsv" ]; then
        echo "--- 4) เฟิร์มแวร์จาก BMC (Redfish) ---"
        awk -F'\t' '{printf "  %-34s %-22s %s\n", $1, $2, $3}' "$OUT/bmc/$host.tsv"
        echo "  >> ตรวจว่ามีรายการของ BMC, GPU, NVSwitch, CPLD ครบตามที่คาดหวัง"
    fi
    echo "--- 5) ไฟล์หลักฐานดิบ ---"
    echo "  $OUT/raw/$host/raw.txt  ($(wc -l < "$OUT/raw/$host/raw.txt") บรรทัด)"
    grep '^#####' "$OUT/raw/$host/raw.txt" | sed 's/^/    /'
    echo
    echo "ผลทั้งหมดอยู่ในโฟลเดอร์: $OUT"
    echo "ถ้ามี error ดูที่: $OUT/err/"
}

# ---------- โหมด all ----------
cmd_all() {
    local hosts=${1:-hosts.txt}
    export BMC_FILE=${2:-bmc.txt}
    [ -f "$hosts" ] || { echo "ไม่พบไฟล์รายชื่อโหนด: $hosts"; exit 1; }
    if [ -f "$BMC_FILE" ]; then ask_bmc_cred; else echo "ไม่พบ $BMC_FILE -> ข้ามการเก็บข้อมูลจาก BMC"; fi
    prepare_out "results_$(date +%Y%m%d_%H%M%S)"
    echo "เริ่มเก็บข้อมูล (พร้อมกันครั้งละ $PARALLEL เครื่อง) -> $OUT"
    grep -v '^[[:space:]]*#' "$hosts" | tr -d '\r' | sed '/^[[:space:]]*$/d' | awk '{print $1}' \
        | xargs -P "$PARALLEL" -I{} bash -c 'job "$1"' _ {}
    finalize
    local total ok
    total=$(grep -v '^[[:space:]]*#' "$hosts" | sed '/^[[:space:]]*$/d' | wc -l)
    ok=$(grep -l 'summary=OK' "$OUT"/status/*.txt 2>/dev/null | wc -l)
    echo "------------------------------------------------"
    echo "โหนดทั้งหมด: $total | เก็บ summary สำเร็จ: $ok"
    echo "ผลทั้งหมดอยู่ในโฟลเดอร์: $OUT"
    echo "  summary.csv / bmc_report.csv / analysis.txt / raw/<โหนด>/raw.txt"
    echo "โหนดที่มีบางส่วนล้มเหลว:"
    grep -h -E 'FAIL' "$OUT"/status/*.txt 2>/dev/null || echo "  (ไม่มี)"
}

case "${1:-}" in
    test) shift; cmd_test "$@" ;;
    all)  shift; cmd_all "$@" ;;
    *)    usage ;;
esac
