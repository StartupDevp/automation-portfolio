#!/bin/bash
# collect_raw.sh - เก็บ "หลักฐานดิบ" ของ 1 โหนด (ผลคำสั่งเต็มๆ) ไว้ตรวจสอบย้อนหลัง
# รันด้วยสิทธิ์ root ผ่าน audit.sh (ไม่ต้องรันเอง)  ผลลัพธ์แบ่งเป็นหัวข้อขึ้นต้นด้วย #####

export LC_ALL=C
export PATH="$PATH:/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/opt/mellanox/doca/tools"

# sec "ชื่อหัวข้อ" 'คำสั่ง'  -> พิมพ์หัวข้อ + ผลคำสั่ง (จำกัดเวลา 60 วินาที, ไม่อ่าน stdin)
sec() {
    echo "##### $1"
    timeout 60 bash -c "$2" 2>&1 </dev/null
    echo "[exit=$?]"
    echo
}

main() {
    sec "time"            'date -Is; hostname -f; uptime'
    sec "os"              'cat /etc/os-release; uname -a'
    sec "packages (doca/ofed/mlnx/nvidia/cuda/fabric/dcgm/mft)" "dpkg -l | grep -i -E 'doca|ofed|mlnx|mft|mstflint|nvidia|cuda|fabricmanager|dcgm|nvlsm|ibverbs'"
    sec "ofed_info -s"    'ofed_info -s'
    sec "kernel modules"  "lsmod | grep -i -E 'nvidia|mlx5|mlx4|ib_core|rdma|peermem|nvidia_fs|gdrdrv'"
    sec "lspci nvidia/mellanox" "lspci -nn | grep -i -E 'mellanox|nvidia|15b3|10de'"
    sec "ConnectX firmware (mstflint q ทุกการ์ด 15b3)" 'for b in $(lspci -D -d 15b3: | grep -v -i "virtual function" | awk "{print \$1}"); do echo "=== $b"; mstflint -d $b q; done'
    sec "mlxfwmanager --query" 'mlxfwmanager --query'
    sec "ibv_devinfo (fw_ver)" "ibv_devinfo | grep -E 'hca_id|fw_ver|node_guid|board_id'"
    sec "ibstat"          'ibstat'
    sec "nvidia-smi"      'nvidia-smi'
    sec "nvidia-smi -q (ละเอียดเต็ม)" 'nvidia-smi -q'
    sec "nvidia-smi topo -m" 'nvidia-smi topo -m'
    sec "nvlink status"   'nvidia-smi nvlink -s'
    sec "fabric manager service" 'systemctl is-active nvidia-fabricmanager; systemctl is-enabled nvidia-fabricmanager; systemctl status nvidia-fabricmanager --no-pager -l | head -n 25'
    sec "dcgm version"    'dcgmi --version'
    sec "ipmi (mc info)"  'modprobe ipmi_devintf; modprobe ipmi_si; ipmitool mc info'
    sec "ipmi (fru)"      'ipmitool fru'
    sec "dmidecode bios/system" 'dmidecode -t bios -t system'
    sec "cpu/memory"      'lscpu | head -n 20; free -h'
}

main "$@"
exit 0
