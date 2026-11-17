#!/bin/bash
# collect_node.sh - เก็บข้อมูลเวอร์ชันของ 1 โหนด แล้วพิมพ์ออกมาเป็น CSV 1 บรรทัด
# ต้องรันด้วยสิทธิ์ root (sudo) เพราะ mstflint / ipmitool / dmidecode ต้องใช้
#   ดูหัวตาราง :  ./collect_node.sh --header
#   รันบนโหนด  :  sudo ./collect_node.sh
#   ปรับ Device ID ของ ConnectX-8 (ถ้าต่างจากค่าเริ่มต้น) :  sudo CX_DEVID=1023 ./collect_node.sh

export LC_ALL=C
export PATH="$PATH:/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/opt/mellanox/doca/tools"
CX_DEVID="${CX_DEVID:-1023}"   # PCI Device ID ของ ConnectX-8 (ยืนยันด้วย: lspci -nn | grep -i mellanox)

HEADER="host,os,kernel,doca_ofed,cx8_count,cx8_fw,gpu_count,gpu_driver,gpu_vbios,cuda,fabricmanager,bmc_fw,bios,cx8_detail"
if [ "${1:-}" = "--header" ]; then
    echo "$HEADER"
    exit 0
fi

# ทำให้ค่าเป็นบรรทัดเดียว, เปลี่ยน comma เป็น ; (กัน CSV เพี้ยน), ถ้าว่างให้เป็น N/A
fmt() {
    local v
    v=$(tr '\n' ' ' | tr ',' ';' | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//')
    [ -n "$v" ] && printf '%s' "$v" || printf 'N/A'
}

host=$(hostname -s)
os=$( (. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") | fmt)
kernel=$(uname -r | fmt)

# 1) DOCA-OFED
doca_ofed=$(ofed_info -s 2>/dev/null | head -n1 | fmt)

# 2) ConnectX-8 firmware (ใช้ PCI address แทน /dev/mst/...)
cx8_count=0
cx8_detail=""
cx8_versions=""
if command -v mstflint >/dev/null 2>&1; then
    for bdf in $(lspci -D -d "15b3:${CX_DEVID}" 2>/dev/null | awk '{print $1}'); do
        ver=$(mstflint -d "$bdf" q 2>/dev/null | awk '/^FW Version:/ {print $3; exit}')
        ver=${ver:-ERR}
        cx8_count=$((cx8_count + 1))
        cx8_detail="$cx8_detail ${bdf}=${ver}"
        cx8_versions="$cx8_versions
$ver"
    done
fi
cx8_fw=$(printf '%s\n' "$cx8_versions" | sed '/^$/d' | sort | uniq -c | awk '{printf "%s%sx%s", (NR>1?"|":""), $2, $1}' | fmt)
cx8_detail=$(printf '%s' "$cx8_detail" | fmt)

# 3) GPU / Driver / VBIOS / CUDA
gpu_count=N/A; gpu_driver=N/A; gpu_vbios=N/A; cuda=N/A
if command -v nvidia-smi >/dev/null 2>&1; then
    gpu_count=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
    gpu_driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | sort -u | paste -sd'|' | fmt)
    gpu_vbios=$(nvidia-smi --query-gpu=vbios_version --format=csv,noheader 2>/dev/null | sort -u | paste -sd'|' | fmt)
    cuda=$(nvidia-smi 2>/dev/null | grep -o 'CUDA Version: *[0-9.]*' | head -n1 | awk '{print $3}' | fmt)
fi

# 4) Fabric Manager (ตัวควบคุม NVSwitch/NVLink ฝั่ง OS)
fabricmanager=$(dpkg-query -W -f='${Package}=${Version}\n' 'nvidia-fabricmanager*' 2>/dev/null | head -n1 | fmt)

# 5) BMC firmware (ผ่าน IPMI) และ BIOS
modprobe ipmi_devintf 2>/dev/null
modprobe ipmi_si 2>/dev/null
bmc_fw=$(timeout 20 ipmitool mc info 2>/dev/null | awk -F': *' '/^Firmware Revision/ {print $2; exit}' | fmt)
bios=$(dmidecode -s bios-version 2>/dev/null | head -n1 | fmt)

echo "${host},${os},${kernel},${doca_ofed},${cx8_count},${cx8_fw},${gpu_count},${gpu_driver},${gpu_vbios},${cuda},${fabricmanager},${bmc_fw},${bios},${cx8_detail}"
