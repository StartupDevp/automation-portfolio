#!/bin/bash
# collect_bmc.sh <ไอพี BMC> - ดึงรายการเวอร์ชันเฟิร์มแวร์ทั้งหมดจาก BMC ผ่าน Redfish
# (BMC, BIOS, CPLD, GPU baseboard, NVSwitch ฯลฯ ตามที่ BMC รายงาน)
# ต้องตั้งตัวแปร BMC_USER และ BMC_PASS ก่อน (audit.sh จัดการให้) ต้องมี jq และ curl บนเครื่อง Admin
# ผลลัพธ์ (stdout): TSV 3 คอลัมน์  Id <TAB> Version <TAB> Name

set -u
ip="${1:?วิธีใช้: collect_bmc.sh <bmc_ip>}"
: "${BMC_USER:?ต้องตั้ง BMC_USER}" "${BMC_PASS:?ต้องตั้ง BMC_PASS}"
command -v jq >/dev/null 2>&1 || { echo "ERROR: ไม่พบ jq (sudo apt install -y jq)" >&2; exit 2; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: ไม่พบ curl" >&2; exit 2; }

# เก็บรหัสผ่านในไฟล์ชั่วคราว (สิทธิ์ 600) แทนการใส่ในบรรทัดคำสั่ง จะได้ไม่โผล่ใน ps / history
esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
CFG=$(mktemp)
chmod 600 "$CFG"
trap 'rm -f "$CFG"' EXIT
printf 'user = "%s:%s"\n' "$(esc "$BMC_USER")" "$(esc "$BMC_PASS")" > "$CFG"

# -k = ไม่ตรวจใบรับรอง (BMC มักใช้ใบรับรองที่เซ็นเอง) ใช้ในเครือข่ายจัดการภายในเท่านั้น
rf() { curl -sk --max-time 30 -K "$CFG" -H 'Accept: application/json' "https://${ip}$1"; }

inv=$(rf /redfish/v1/UpdateService/FirmwareInventory)
if ! printf '%s' "$inv" | jq -e '.Members' >/dev/null 2>&1; then
    echo "ERROR: อ่าน FirmwareInventory จาก $ip ไม่ได้ (รหัสผิด/เข้าถึงไม่ได้/BMC ไม่รองรับ): $(printf '%s' "$inv" | head -c 300)" >&2
    exit 3
fi

{
    for u in $(printf '%s' "$inv" | jq -r '.Members[]."@odata.id"'); do
        rf "$u" | jq -r '[(.Id // "unknown"), (.Version // "N/A"), (.Name // "")] | @tsv'
    done
    mgr=$(rf /redfish/v1/Managers | jq -r '.Members[0]."@odata.id" // empty')
    if [ -n "$mgr" ]; then
        rf "$mgr" | jq -r '[("Manager_" + (.Id // "x") + "_FirmwareVersion"), (.FirmwareVersion // "N/A"), "Manager firmware"] | @tsv'
    fi
} | sort
