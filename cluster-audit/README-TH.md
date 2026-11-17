# คู่มือตรวจสอบเวอร์ชัน Driver / Firmware ของคลัสเตอร์ NVIDIA B300 (48 โหนด)
**Cluster Version Audit Guide for 48-Node NVIDIA B300 Servers (Ubuntu)**

> สำหรับผู้ที่ **ยังไม่คุ้นเคยกับ Linux** — ทุกขั้นตอนมีคำสั่งให้คัดลอกไปวางได้เลย พร้อมคำอธิบายว่าคำสั่งทำอะไร ผลลัพธ์ที่ถูกต้องควรเป็นอย่างไร และถ้าผิดพลาดให้แก้อย่างไร
>
> ระบบปฏิบัติการ: **Ubuntu** ทั้งหมด (ทั้งเครื่อง Admin และ 48 โหนด B300) — คู่มือนี้ทดสอบความถูกต้องของสคริปต์บน Ubuntu 24.04 (ใช้ได้กับ 22.04 ด้วย)

---

## สารบัญ (Table of Contents)

0. ภาพรวมและสิ่งที่จะได้ (Overview)
1. พื้นฐาน Linux ที่ต้องรู้ก่อนเริ่ม (Linux Basics)
2. เตรียมเครื่อง Admin (Prepare the Admin Machine)
3. สร้างโฟลเดอร์งานและรายชื่อโหนด (Working Folder & Host List)
4. ตั้งค่า SSH แบบไม่ต้องใช้รหัสผ่าน (SSH Key Trust)
5. ตั้งค่า sudo และติดตั้งเครื่องมือบนโหนด (sudo & Tools on Nodes)
6. ทดสอบกับ 1 โหนดก่อน (Test on One Node First)
7. วิธีที่ 1: Ansible (Recommended)
8. วิธีที่ 2: Bash Script แบบขนาน (Alternative)
9. วิเคราะห์ผล หาโหนดที่เวอร์ชันไม่ตรง (Analyze Results)
10. เสริม: BMC / NVSwitch ผ่าน Redfish (Optional)
11. การแก้ไขโหนดที่เวอร์ชันไม่ตรง (Remediation)
12. แก้ปัญหาที่พบบ่อย (Troubleshooting)
13. สรุปข้อผิดพลาดที่พบและแก้ไขจากเอกสารต้นฉบับ (Corrections to the Original)
14. สรุปคำสั่งย่อ (Cheat Sheet)
15. ภาคผนวก: โค้ดฉบับเต็ม (Appendix: Full Source Files)

---

## 0. ภาพรวมและสิ่งที่จะได้ (Overview)

### 0.1 เป้าหมาย
คลัสเตอร์ B300 จำนวน 48 โหนด ควรใช้ **เวอร์ชันซอฟต์แวร์/เฟิร์มแวร์เหมือนกันทุกเครื่อง** (เรียกว่า *golden combination*) ถ้ามีบางเครื่องไม่ตรง (เช่น ถูกอัปเกรดด้วยมือหลังส่งมอบ) อาจทำให้งาน AI/HPC ช้าลง, เกิด error แปลกๆ หรือเครือข่าย InfiniBand/RoCE มีปัญหา

คู่มือนี้ช่วยให้คุณ **เก็บเวอร์ชันจากทั้ง 48 เครื่องอัตโนมัติ → ได้ไฟล์ CSV เดียว → ดูได้ทันทีว่าเครื่องไหนต่างจากส่วนใหญ่**

### 0.2 ข้อมูลที่เก็บ (ต่อ 1 โหนด)

| คอลัมน์ใน CSV | ความหมาย | ได้มาจาก (คำสั่ง) |
|---|---|---|
| `host` | ชื่อเครื่อง | `hostname -s` |
| `os` | เวอร์ชัน Ubuntu | `/etc/os-release` |
| `kernel` | เวอร์ชัน Linux kernel | `uname -r` |
| `doca_ofed` | เวอร์ชัน DOCA-OFED (ไดรเวอร์เครือข่ายชุดใหญ่ของ NVIDIA) | `ofed_info -s` |
| `cx8_count` | จำนวนการ์ด/พอร์ต ConnectX-8 ที่พบ | `lspci` |
| `cx8_fw` | เวอร์ชันเฟิร์มแวร์ ConnectX-8 (สรุป เช่น `40.47.1026x8` = เวอร์ชันนี้ 8 ตัว) | `mstflint -d <PCI> q` |
| `gpu_count` | จำนวน GPU | `nvidia-smi -L` |
| `gpu_driver` | เวอร์ชัน GPU Driver | `nvidia-smi` |
| `gpu_vbios` | เวอร์ชัน VBIOS ของ GPU | `nvidia-smi` |
| `cuda` | เวอร์ชัน CUDA ที่ Driver รองรับ | `nvidia-smi` |
| `fabricmanager` | เวอร์ชัน NVIDIA Fabric Manager (ตัวคุมการเชื่อมต่อ NVSwitch/NVLink ฝั่ง OS) | `dpkg-query` |
| `bmc_fw` | เวอร์ชันเฟิร์มแวร์ BMC (ผ่าน IPMI) | `ipmitool mc info` |
| `bios` | เวอร์ชัน BIOS | `dmidecode` |
| `cx8_detail` | รายละเอียดเฟิร์มแวร์ทีละการ์ด (ที่อยู่ PCI = เวอร์ชัน) | `mstflint` |

> **หมายเหตุสำคัญ:** เวอร์ชันของ **NVSwitch firmware** และ **BMC แบบเต็ม** มักดูได้ครบที่สุดผ่าน BMC (Redfish) ไม่ใช่จากใน OS — ดูหัวข้อ 10

### 0.3 ภาพรวมขั้นตอน (Workflow)

```
[เครื่อง Admin]                                   [โหนด B300 x 48]
  1. เตรียมเครื่องมือ (หัวข้อ 2-3)
  2. ตั้ง SSH key + sudo (หัวข้อ 4-5)  ─────────►  ผู้ใช้ gsops เข้าได้โดยไม่ถามรหัส
  3. ทดสอบ 1 โหนด (หัวข้อ 6)           ─────────►  รัน collect_node.sh ได้ผลถูกต้อง
  4. รันทั้ง 48 โหนด (หัวข้อ 7 หรือ 8) ─────────►  ส่งสคริปต์ไปรันทีละเครื่องแบบขนาน
  5. ได้ไฟล์ CSV                      ◄─────────  เก็บผลกลับมา
  6. วิเคราะห์ (หัวข้อ 9)  → รู้ว่าโหนดไหนผิดปกติ
```

### 0.4 เลือกวิธีไหน?
| | วิธีที่ 1 Ansible | วิธีที่ 2 Bash |
|---|---|---|
| ต้องติดตั้งเพิ่ม | ต้อง (`apt install ansible`) | ไม่ต้อง |
| เหมาะกับ | ใช้งานซ้ำบ่อยๆ, ขยายไปงานอื่นต่อ | ใช้เร็ว ครั้งเดียว |
| ผลลัพธ์ | `cluster_version_report.csv` | `version_audit_<เวลา>.csv` |
| ทั้งสองวิธีใช้สคริปต์เก็บข้อมูลตัวเดียวกัน | `collect_node.sh` | `collect_node.sh` |

**แนะนำ:** ถ้าไม่เคยใช้ Ansible และต้องการให้เสร็จเร็ว ให้เริ่มจาก **วิธีที่ 2 (Bash)** ก่อนก็ได้ เพราะไม่ต้องติดตั้งอะไรเพิ่ม

---

## 1. พื้นฐาน Linux ที่ต้องรู้ก่อนเริ่ม (Linux Basics)

### 1.1 Terminal และเครื่องหมาย Prompt
Terminal คือหน้าจอพิมพ์คำสั่ง (เปิดบน Ubuntu ด้วย `Ctrl + Alt + T` หรือเข้าผ่าน SSH/PuTTY) บรรทัดที่เห็นจะหน้าตาประมาณนี้:

```
gsops@admin01:~$
```
- `gsops` = ชื่อผู้ใช้, `admin01` = ชื่อเครื่อง, `~` = โฟลเดอร์ปัจจุบัน (home), `$` = พร้อมรับคำสั่ง
- **ในคู่มือนี้ ไม่ต้องพิมพ์เครื่องหมาย `$`** — พิมพ์เฉพาะคำสั่ง แล้วกด `Enter`
- วางข้อความใน Terminal: `Ctrl + Shift + V` (ไม่ใช่ Ctrl+V) / ยกเลิกคำสั่งที่กำลังรัน: `Ctrl + C`

### 1.2 คำสั่งพื้นฐานที่ใช้ในคู่มือนี้

| คำสั่ง | ทำอะไร | ตัวอย่าง |
|---|---|---|
| `pwd` | แสดงว่าตอนนี้อยู่โฟลเดอร์ไหน | `pwd` |
| `ls -l` | แสดงรายการไฟล์ในโฟลเดอร์ | `ls -l` |
| `cd โฟลเดอร์` | เข้าไปในโฟลเดอร์ | `cd ~/cluster-audit` |
| `mkdir โฟลเดอร์` | สร้างโฟลเดอร์ | `mkdir ~/cluster-audit` |
| `cat ไฟล์` | แสดงเนื้อหาไฟล์ทั้งหมด | `cat hosts.txt` |
| `head -n 5 ไฟล์` | แสดง 5 บรรทัดแรก | `head -n 5 report.csv` |
| `nano ไฟล์` | เปิดตัวแก้ไขไฟล์ (ดู 1.3) | `nano hosts.txt` |
| `chmod +x ไฟล์` | ทำให้ไฟล์รันเป็นโปรแกรมได้ | `chmod +x collect_node.sh` |
| `./ชื่อไฟล์` | รันสคริปต์ในโฟลเดอร์ปัจจุบัน | `./check_versions.sh` |
| `sudo คำสั่ง` | รันคำสั่งด้วยสิทธิ์ผู้ดูแล (root) — จะถามรหัสผ่านของคุณ | `sudo apt update` |
| `ssh user@host` | เข้าไปควบคุมเครื่องอื่นจากระยะไกล | `ssh gsops@b300-node01` |
| `exit` | ออกจาก ssh กลับเครื่องเดิม | `exit` |
| `scp` | คัดลอกไฟล์ระหว่างเครื่อง | `scp ไฟล์ user@host:/path/` |
| `Tab` | กด Tab เพื่อเติมชื่อไฟล์/คำสั่งอัตโนมัติ (ช่วยลดการพิมพ์ผิด) | — |
| `↑` (ลูกศรขึ้น) | เรียกคำสั่งก่อนหน้ากลับมา | — |

### 1.3 การแก้ไขไฟล์ด้วย `nano` (ง่ายที่สุด)
```bash
nano hosts.txt
```
- พิมพ์/วางเนื้อหาได้เลย
- **บันทึก:** `Ctrl + O` แล้วกด `Enter`
- **ออก:** `Ctrl + X`
- (ถ้าถามว่า Save modified buffer? ให้กด `Y` แล้ว `Enter`)

### 1.4 กฎสำคัญเรื่องการคัดลอกคำสั่ง
1. **Linux แยกตัวพิมพ์เล็ก/ใหญ่** (`Hosts.txt` ≠ `hosts.txt`)
2. **เว้นวรรคมีความหมาย** — ห้ามเพิ่ม/ลบเอง
3. เมื่อเห็น `<...>` เช่น `<ชื่อโหนด>` ให้ **แทนที่ด้วยค่าจริงของคุณ** (และไม่ต้องพิมพ์เครื่องหมาย `<` `>`)
4. คำสั่งที่ขึ้นต้นด้วย `#` คือหมายเหตุ ไม่ได้รันอะไร

---

## 2. เตรียมเครื่อง Admin (Prepare the Admin Machine)

เครื่อง Admin คือเครื่องที่คุณนั่งสั่งงาน (เป็นหนึ่งใน 48 โหนด หรือเป็นเครื่องจัดการแยกต่างหากก็ได้) ต้องเป็น Ubuntu และเข้า SSH ไปยังทุกโหนดได้

### 2.1 เช็กเวอร์ชัน Ubuntu
```bash
lsb_release -ds
```
ผลที่ควรเห็น เช่น `Ubuntu 24.04.1 LTS`

### 2.2 อัปเดตรายการแพ็กเกจและติดตั้งเครื่องมือพื้นฐาน
```bash
sudo apt update
sudo apt install -y openssh-client openssh-server coreutils gawk sed grep findutils pciutils jq curl
```
- `sudo` จะถามรหัสผ่านของคุณ (พิมพ์แล้วไม่ขึ้นตัวอักษรใดๆ เป็นเรื่องปกติ ให้พิมพ์ต่อแล้วกด Enter)
- `apt update` = ดึงรายการแพ็กเกจล่าสุด, `apt install -y` = ติดตั้งโดยตอบ yes อัตโนมัติ

### 2.3 (เฉพาะวิธีที่ 1) ติดตั้ง Ansible
```bash
sudo apt install -y ansible
ansible --version
```
ผลที่ควรเห็น: บรรทัดแรกขึ้นต้นด้วย `ansible [core 2.xx.x]`

> ถ้าเครื่อง Admin **ไม่มีอินเทอร์เน็ต**: ให้ใช้ **วิธีที่ 2 (Bash)** หรือขอไฟล์ `.deb` / ตั้ง apt mirror ภายในองค์กรจากทีมโครงสร้างพื้นฐาน

---

## 3. สร้างโฟลเดอร์งานและรายชื่อโหนด (Working Folder & Host List)

### 3.1 สร้างโฟลเดอร์
```bash
mkdir -p ~/cluster-audit
cd ~/cluster-audit
pwd
```
`pwd` ควรแสดง `/home/<ชื่อผู้ใช้>/cluster-audit`

### 3.2 นำไฟล์สคริปต์มาไว้ในโฟลเดอร์นี้
ไฟล์ที่ต้องมี (โค้ดฉบับเต็มอยู่ในภาคผนวกหัวข้อ 15 — สร้างไฟล์ด้วย `nano` แล้ววางเนื้อหา):

| ไฟล์ | ใช้กับ | หน้าที่ |
|---|---|---|
| `collect_node.sh` | ทั้งสองวิธี | เก็บเวอร์ชันของ 1 โหนด |
| `check_versions.sh` | วิธีที่ 2 | วนเก็บ 48 โหนดแบบขนาน |
| `get_versions.yml` | วิธีที่ 1 | Ansible playbook |
| `ansible.cfg` | วิธีที่ 1 | ตั้งค่า Ansible |
| `analyze.sh` | ทั้งสองวิธี | วิเคราะห์หาโหนดที่ต่างจากส่วนใหญ่ |
| `hosts.txt` | วิธีที่ 2 | รายชื่อโหนด |
| `inventory.ini` | วิธีที่ 1 | รายชื่อโหนดสำหรับ Ansible |

ตัวอย่างการสร้างไฟล์ `collect_node.sh`:
```bash
nano collect_node.sh
# วางโค้ดจากภาคผนวก 15.1 → Ctrl+O, Enter, Ctrl+X
chmod +x collect_node.sh check_versions.sh analyze.sh
ls -l
```
ผลที่ควรเห็น: ไฟล์ `.sh` มีตัว `x` ในสิทธิ์ เช่น `-rwxr-xr-x`

> **ทางลัด:** ถ้าไฟล์ทั้งหมดอยู่ใน Git repository ให้ `git clone` แล้วเข้าโฟลเดอร์ `cluster-audit` ได้เลย ไม่ต้องสร้างทีละไฟล์

> **ข้อควรระวังเมื่อคัดลอกจาก Windows:** ถ้าสคริปต์มีอักขระขึ้นบรรทัดแบบ Windows (CRLF) จะรันไม่ได้ (ขึ้น `^M` หรือ `bad interpreter`) แก้ด้วย:
> ```bash
> sed -i 's/\r$//' *.sh *.yml *.txt
> ```

### 3.3 สร้างรายชื่อโหนด

**สำหรับวิธีที่ 2 (Bash):** สร้าง `hosts.txt` — 1 บรรทัดต่อ 1 โหนด (hostname หรือ IP)
```bash
nano hosts.txt
```
ตัวอย่างเนื้อหา:
```
# รายชื่อโหนด B300
b300-node01
b300-node02
b300-node03
# ... ไปจนถึง b300-node48
```

> **ทางลัดสร้างรายชื่อ 48 บรรทัดอัตโนมัติ** (ถ้าชื่อเรียงเลขต่อเนื่อง ปรับชื่อให้ตรงกับของจริง):
> ```bash
> for i in $(seq -w 1 48); do echo "b300-node$i"; done > hosts.txt
> wc -l hosts.txt
> ```
> `wc -l` ควรแสดง `48 hosts.txt`

**สำหรับวิธีที่ 1 (Ansible):** สร้าง `inventory.ini`
```ini
[b300]
b300-node[01:48]
```
(รูปแบบ `[01:48]` ของ Ansible จะขยายเป็น node01 ถึง node48 ให้เอง; ถ้าใช้ IP ให้ใส่ทีละบรรทัด)

### 3.4 ตรวจว่าเครื่อง Admin หาชื่อโหนดเจอ
```bash
getent hosts b300-node01
ping -c 2 b300-node01
```
ถ้าไม่เจอ ให้ใช้ IP แทนชื่อใน `hosts.txt` / `inventory.ini` หรือเพิ่มชื่อใน `/etc/hosts` (ปรึกษาทีมเครือข่าย)

---

## 4. ตั้งค่า SSH แบบไม่ต้องใช้รหัสผ่าน (SSH Key Trust)

สคริปต์ต้อง login 48 เครื่องอัตโนมัติ จึงต้องใช้ **SSH key** แทนรหัสผ่าน

> **ถ้าองค์กรของคุณตั้งค่า SSH key ให้ผู้ใช้ `gsops` ไว้แล้ว** ให้ข้ามไป 4.4 เพื่อทดสอบ

### 4.1 สร้างคู่กุญแจ (ทำครั้งเดียวบนเครื่อง Admin)
```bash
ls ~/.ssh/id_ed25519.pub
```
- ถ้าแสดงไฟล์ = มี key แล้ว ข้ามไป 4.2
- ถ้าขึ้น `No such file` ให้สร้าง:
```bash
ssh-keygen -t ed25519 -C "cluster-audit"
```
กด `Enter` ตามคำถามเรื่องตำแหน่งไฟล์ (ใช้ค่าเริ่มต้น) และ passphrase: ใส่ passphrase เพื่อความปลอดภัยแนะนำ (ถ้าใส่ ให้ทำ 4.3 ด้วย) หรือเว้นว่างถ้านโยบายองค์กรอนุญาต

### 4.2 ส่ง public key ไปยังทุกโหนด
```bash
cd ~/cluster-audit
for h in $(grep -v '^#' hosts.txt | sed '/^$/d'); do
  echo "=== $h ==="
  ssh-copy-id -o StrictHostKeyChecking=accept-new gsops@"$h"
done
```
- ระบบจะถามรหัสผ่านของ `gsops` ทีละโหนด (48 ครั้ง) — ทำครั้งเดียวเท่านั้น
- `StrictHostKeyChecking=accept-new` = ยอมรับ fingerprint ของเครื่องใหม่ครั้งแรกอัตโนมัติ (ปลอดภัยพอสำหรับเครือข่ายภายใน; เครื่องที่เปลี่ยน key ภายหลังจะถูกปฏิเสธ)
- ถ้าผู้ใช้ไม่ใช่ `gsops` ให้เปลี่ยนชื่อผู้ใช้ให้ตรงกับของคุณ

### 4.3 (ถ้าตั้ง passphrase) โหลด key เข้า ssh-agent
เพื่อไม่ต้องพิมพ์ passphrase ทุกครั้งที่ต่อเครื่อง:
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```
ต้องทำใหม่ทุกครั้งที่เปิด Terminal ใหม่

### 4.4 ทดสอบว่าเข้าได้ครบทุกโหนดโดยไม่ถามรหัส
```bash
for h in $(grep -v '^#' hosts.txt | sed '/^$/d'); do
  printf '%-20s ' "$h"
  ssh -o BatchMode=yes -o ConnectTimeout=5 gsops@"$h" hostname 2>&1 | tail -n 1
done
```
**ผลที่ถูกต้อง:** ทุกบรรทัดแสดงชื่อเครื่องจริงต่อท้าย
**ถ้าบรรทัดไหนขึ้น `Permission denied`** = key ยังไม่ถูกส่งไปเครื่องนั้น (กลับไปทำ 4.2 เฉพาะเครื่องนั้น)
**ถ้าขึ้น `Connection timed out`** = เข้าถึงเครือข่ายไม่ได้/เครื่องปิดอยู่ (ดูหัวข้อ 12)

---

## 5. ตั้งค่า sudo และติดตั้งเครื่องมือบนโหนด (sudo & Tools on Nodes)

คำสั่ง `mstflint`, `ipmitool`, `dmidecode` ต้องใช้สิทธิ์ root สคริปต์จะเรียก `sudo` บนโหนด **โดยไม่มีคนพิมพ์รหัสผ่าน** จึงต้องมี sudo แบบไม่ถามรหัส (NOPASSWD)

### 5.1 เช็กก่อนว่ามีอยู่แล้วหรือยัง
```bash
ssh gsops@b300-node01 'sudo -n true && echo SUDO_OK || echo SUDO_NEEDS_PASSWORD'
```
- `SUDO_OK` = พร้อมแล้ว ข้ามไป 5.3
- `SUDO_NEEDS_PASSWORD` / `a password is required` = ทำ 5.2

### 5.2 ตั้งค่า NOPASSWD (ทำบนทุกโหนด — ต้องได้รับอนุญาตจากผู้ดูแลระบบ/นโยบายความปลอดภัยก่อน)
เข้าไปที่โหนด:
```bash
ssh -t gsops@b300-node01
```
แล้วรันบนโหนด:
```bash
echo 'gsops ALL=(root) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/90-gsops-audit
sudo chmod 440 /etc/sudoers.d/90-gsops-audit
sudo visudo -cf /etc/sudoers.d/90-gsops-audit
exit
```
- `visudo -cf` ตรวจไวยากรณ์ — ต้องขึ้น `parsed OK` (ถ้าไม่ OK ให้ลบไฟล์ `sudo rm /etc/sudoers.d/90-gsops-audit` ก่อน ไม่งั้นอาจล็อกตัวเองออกจาก sudo)
- ถ้าองค์กรไม่อนุญาต NOPASSWD: ใช้วิธีที่ 1 (Ansible) แล้วรันด้วยตัวเลือก `-K` (ถามรหัส sudo ครั้งเดียวใช้กับทุกโหนด ถ้ารหัสเหมือนกัน)

> ความปลอดภัย: ถ้าต้องการจำกัดสิทธิ์ให้แคบลง ปรึกษาทีม Security — สคริปต์นี้ต้องรัน `bash -s` ด้วย sudo จึงต้องมีสิทธิ์กว้างพอสมควร

### 5.3 ติดตั้งเครื่องมือที่โหนดต้องใช้
ทำบน **ทุกโหนด** (ใช้ loop รันจากเครื่อง Admin):
```bash
for h in $(grep -v '^#' hosts.txt | sed '/^$/d'); do
  echo "=== $h ==="
  ssh -o BatchMode=yes gsops@"$h" 'sudo -n apt-get install -y mstflint ipmitool pciutils dmidecode' 2>&1 | tail -n 2
done
```
- **ต้องมีอินเทอร์เน็ตหรือ apt mirror ภายใน** บนโหนด ถ้าไม่มีให้ติดตั้งแพ็กเกจจาก repository ภายในองค์กร
- ปกติ DOCA-OFED จะติดตั้ง `mstflint` มาให้อยู่แล้ว และ `ofed_info` มาจากแพ็กเกจ DOCA-OFED (ไม่ต้องติดตั้งเพิ่ม)
- **หมายเหตุ:** เอกสารต้นฉบับใช้ `mst status` (มาจากชุด NVIDIA MFT) คู่กับ `mstflint` ซึ่ง **ไม่จำเป็น** — `mstflint` ระบุการ์ดด้วยที่อยู่ PCI (เช่น `0000:18:00.0`) ได้โดยตรง ไม่ต้องใช้ `/dev/mst/...` คู่มือนี้จึงใช้ `lspci` + `mstflint` เท่านั้น

### 5.4 ตรวจสอบว่าเครื่องมือครบ
```bash
ssh gsops@b300-node01 'for c in ofed_info mstflint lspci nvidia-smi ipmitool dmidecode; do printf "%-12s " $c; command -v $c || echo "ไม่พบ"; done'
```
ทุกบรรทัดควรแสดง path เช่น `/usr/bin/mstflint` ถ้า `ไม่พบ` ตัวไหน ค่าของคอลัมน์ที่เกี่ยวข้องจะเป็น `N/A` ในรายงาน

---

## 6. ทดสอบกับ 1 โหนดก่อน (Test on One Node First)

**ทดสอบเครื่องเดียวให้ผ่านก่อนรัน 48 เครื่องเสมอ** จะได้เจอปัญหาเร็ว

### 6.1 ดูคำสั่งแต่ละตัวด้วยมือ (เข้าใจว่าสคริปต์ทำอะไร)
เข้าโหนด:
```bash
ssh gsops@b300-node01
```

**(ก) DOCA-OFED**
```bash
ofed_info -s
```
ผลตัวอย่าง: สตริงเวอร์ชัน เช่น `MLNX_OFED_LINUX-xx.xx-x.x.x.x:` หรือรูปแบบ `OFED-internal-...` (รูปแบบขึ้นกับชุดติดตั้ง)

**(ข) ค้นหาการ์ด ConnectX-8**
```bash
lspci -nn | grep -i mellanox
```
ผลตัวอย่าง: บรรทัดที่มี `[15b3:xxxx]` — `15b3` คือรหัสผู้ผลิต (NVIDIA/Mellanox) ส่วนหลัง `:` คือรหัสรุ่น (Device ID)
- ConnectX-8 โดยปกติใช้ Device ID **`1023`** (สคริปต์ตั้งเป็นค่าเริ่มต้น)
- **ถ้าของคุณขึ้นรหัสอื่น** (หรือมี BlueField / ConnectX-7 ปนอยู่) ให้ดูว่ารุ่นไหนคือ CX8 แล้วรันสคริปต์ด้วย `CX_DEVID=<รหัสของคุณ>` (ดู 6.2)
- เทียบกับบรรทัดคำอธิบายที่ `lspci` แสดง (เช่น `ConnectX-8`) หากฐานข้อมูล PCI เก่า อาจแสดงเป็นชื่อ `Device 1023`

**(ค) เวอร์ชันเฟิร์มแวร์ของการ์ด 1 ใบ** (แทน `0000:18:00.0` ด้วยที่อยู่ PCI ที่ได้จาก (ข) — คอลัมน์แรกของ `lspci`)
```bash
sudo mstflint -d 0000:18:00.0 q
```
ผลตัวอย่าง:
```
Image type:            FS4
FW Version:            40.xx.xxxx
...
PSID:                  MT_xxxxxxxxxx
```
บรรทัด `FW Version` คือเวอร์ชันที่ต้องการ

**(ง) GPU Driver / VBIOS / CUDA**
```bash
nvidia-smi
nvidia-smi --query-gpu=index,driver_version,vbios_version --format=csv
```
`nvidia-smi` แสดง Driver Version และ CUDA Version ที่มุมบนขวา; คำสั่งที่สองแสดงเป็นตาราง 8 บรรทัด (1 บรรทัดต่อ GPU)

**(จ) Fabric Manager (NVSwitch/NVLink)**
```bash
dpkg-query -W -f='${Package}=${Version}\n' 'nvidia-fabricmanager*'
systemctl is-active nvidia-fabricmanager
```
ผลควรเป็นเวอร์ชันที่ **ตรงกับ GPU Driver** และสถานะ `active`

**(ฉ) BMC และ BIOS**
```bash
sudo modprobe ipmi_devintf
sudo modprobe ipmi_si
sudo ipmitool mc info | grep -i 'Firmware Revision'
sudo dmidecode -s bios-version
```
`ipmitool` ต้องการโมดูล kernel IPMI — คำสั่ง `modprobe` ด้านบนโหลดให้
ออกจากโหนด: `exit`

### 6.2 รันสคริปต์เก็บข้อมูลบนโหนดนั้นจริงๆ จากเครื่อง Admin
```bash
cd ~/cluster-audit
./collect_node.sh --header
ssh gsops@b300-node01 'sudo -n bash -s' < collect_node.sh
```
- บรรทัดแรกคือหัวคอลัมน์ บรรทัดที่สองคือข้อมูลของโหนด (ค่าที่เก็บไม่ได้จะเป็น `N/A`)
- ถ้า Device ID ของ ConnectX-8 ไม่ใช่ `1023`:
```bash
ssh gsops@b300-node01 'sudo -n env CX_DEVID=<รหัสของคุณ> bash -s' < collect_node.sh
```
(หรือแก้ค่าบรรทัด `CX_DEVID="${CX_DEVID:-1023}"` ใน `collect_node.sh` เป็นรหัสที่ถูกต้อง)

**เกณฑ์ผ่าน:** ไม่มี `N/A` ในคอลัมน์ที่คุณคาดว่าต้องมีค่า (`doca_ofed`, `cx8_fw`, `gpu_driver` ฯลฯ) ถ้ามี `N/A` ให้ตรวจเครื่องมือตามหัวข้อ 5.4 และ 12

---

## 7. วิธีที่ 1: Ansible (Recommended)

Ansible = โปรแกรมสั่งงานหลายเครื่องพร้อมกันผ่าน SSH ใช้ไฟล์ YAML บอกว่าต้องทำอะไร

### 7.1 ไฟล์ที่ใช้ (โค้ดเต็มในภาคผนวก 15.4–15.5)
- `ansible.cfg` — ตั้งผู้ใช้ `gsops`, ทำงานพร้อมกัน 48 เครื่อง (`forks = 48`; ค่าเริ่มต้นของ Ansible คือ 5 ซึ่งจะช้า)
- `inventory.ini` — รายชื่อโหนด
- `get_versions.yml` — playbook 3 ขั้นตอน: (1) เตรียมโฟลเดอร์ `reports/` (2) ส่ง `collect_node.sh` ไปรันทุกโหนดแล้วเซฟผลโหนดละ 1 ไฟล์ (3) รวมเป็น `cluster_version_report.csv`

> เหตุที่ออกแบบให้เซฟ "ไฟล์ละโหนด" แล้วค่อยรวม: ต้นฉบับใช้ `lineinfile` เขียนไฟล์เดียวกันจากหลายเครื่องพร้อมกัน ซึ่งอาจทำให้บรรทัดตกหล่น/ทับกัน (race condition)

### 7.2 ทดสอบการเชื่อมต่อ
```bash
cd ~/cluster-audit
ansible all -i inventory.ini -m ping
```
**ผลที่ถูกต้อง:** ทุกโหนดขึ้น `SUCCESS` พร้อม `"ping": "pong"`
ถ้ามีโหนดขึ้น `UNREACHABLE` ให้แก้ที่ SSH (หัวข้อ 4, 12)

### 7.3 ตรวจไวยากรณ์ playbook ก่อนรัน
```bash
ansible-playbook -i inventory.ini get_versions.yml --syntax-check
```
ควรขึ้นชื่อไฟล์ `playbook: get_versions.yml` โดยไม่มี error

### 7.4 รัน
```bash
ansible-playbook -i inventory.ini get_versions.yml
```
- ถ้า sudo บนโหนดต้องพิมพ์รหัสผ่าน ให้เพิ่ม `-K` (`--ask-become-pass`):
  `ansible-playbook -i inventory.ini get_versions.yml -K`
- ถ้าใช้ SSH key ที่มี passphrase ให้ทำ 4.3 ก่อน
- เมื่อเสร็จ ดูท้ายจอ **PLAY RECAP**: ทุกโหนดควรมี `failed=0 unreachable=0`

### 7.5 ผลลัพธ์
```bash
head -n 3 cluster_version_report.csv
wc -l cluster_version_report.csv
```
`wc -l` ควรได้ **49** บรรทัด (หัวตาราง 1 + 48 โหนด)
ไฟล์แยกรายโหนดอยู่ที่ `reports/<ชื่อโหนด>.csv`

### 7.6 กรณีบางโหนดล้มเหลว
Ansible จะรันโหนดอื่นต่อ และสรุปโหนดที่ล้มเหลวใน PLAY RECAP — ให้แก้ปัญหาโหนดนั้น แล้วรันซ้ำเฉพาะโหนดนั้นได้ด้วย `--limit`:
```bash
ansible-playbook -i inventory.ini get_versions.yml --limit b300-node07
```
(แต่หมายเหตุ: playbook จะล้างโฟลเดอร์ `reports/` ทุกครั้ง การรันซ้ำเฉพาะโหนดเดียวจะได้ CSV ที่มีโหนดเดียว — ให้รันทั้งหมดอีกรอบเมื่อแก้ครบแล้ว)

---

## 8. วิธีที่ 2: Bash Script แบบขนาน (Alternative)

ไม่ต้องติดตั้งอะไรเพิ่ม ใช้ `check_versions.sh` (โค้ดเต็มในภาคผนวก 15.2) ซึ่งทำงาน: อ่าน `hosts.txt` → ส่ง `collect_node.sh` ผ่าน SSH ไปรันด้วย `sudo` บนแต่ละโหนด (พร้อมกันครั้งละ 16 เครื่อง) → รวมผลเป็น CSV

### 8.1 รัน
```bash
cd ~/cluster-audit
./check_versions.sh hosts.txt
```
ปรับค่าได้ผ่านตัวแปร (ไม่ต้องแก้ไฟล์):
```bash
SSH_USER=gsops PARALLEL=24 ./check_versions.sh hosts.txt
```

### 8.2 ผลที่ควรเห็น
```
[ OK ] b300-node03
[ OK ] b300-node01
...
-----------------------------------------
สำเร็จ: 48 โหนด | ล้มเหลว: 0 โหนด
รายงาน: /home/<user>/cluster-audit/version_audit_20260101_101500.csv
```
- ลำดับ OK ไม่เรียงกัน เป็นเรื่องปกติ (รันขนาน)
- ถ้ามี `[FAIL]` สคริปต์จะบอกชื่อไฟล์ที่เก็บ error ไว้ (`audit_<เวลา>/err/<โหนด>.txt`) ให้เปิดดูด้วย `cat`

### 8.3 ตรวจผล
```bash
ls -lt version_audit_*.csv | head -n 1
wc -l version_audit_*.csv
```
ควรได้ 49 บรรทัดเมื่อสำเร็จครบ

### 8.4 รันซ้ำเฉพาะโหนดที่ล้มเหลว
สร้างรายชื่อใหม่เฉพาะโหนดที่ล้มเหลวแล้วรันอีกครั้ง:
```bash
nano failed_hosts.txt     # ใส่ชื่อโหนดที่ล้มเหลว
./check_versions.sh failed_hosts.txt
```
จากนั้นนำผลมารวมกับรอบแรก:
```bash
{ ./collect_node.sh --header; cat audit_*/raw/*.csv | sort -u; } > merged_report.csv
```

---

## 9. วิเคราะห์ผล หาโหนดที่เวอร์ชันไม่ตรง (Analyze Results)

### 9.1 ใช้สคริปต์ `analyze.sh` (แนะนำ)
```bash
./analyze.sh cluster_version_report.csv        # ถ้าใช้ Ansible
./analyze.sh version_audit_XXXXXXXX_XXXXXX.csv # ถ้าใช้ Bash (ใส่ชื่อไฟล์จริง)
```
ตัวอย่างผล:
```
== doca_ofed ==  (ค่าไม่ซ้ำกัน 2 แบบ)
   47  MLNX_OFED_LINUX-xx.xx-x.x.x.x
    1  MLNX_OFED_LINUX-yy.yy-y.y.y.y
  >> ค่าส่วนใหญ่: MLNX_OFED_LINUX-xx.xx-x.x.x.x
  >> OUTLIER  b300-node17     MLNX_OFED_LINUX-yy.yy-y.y.y.y
```
- ตัวเลขหน้าคือจำนวนโหนดที่ใช้เวอร์ชันนั้น
- `OUTLIER` = โหนดที่ **ต่างจากค่าส่วนใหญ่** → ต้องตรวจสอบ
- `ค่าไม่ซ้ำกัน 1 แบบ` = ทุกโหนดตรงกัน (ปกติ)
- คอลัมน์ `cx8_fw` ที่เป็น `40.47.1026x8|40.45.1020x1` แปลว่าในโหนดเดียวมีการ์ดคนละเวอร์ชันปนกัน (ควรตรวจทันที)

> ข้อควรระวัง: "ค่าส่วนใหญ่" ไม่ได้แปลว่าถูกต้องเสมอไป — ให้ตรวจเทียบกับเวอร์ชัน golden ที่ผ่านการรับรอง/เอกสารส่งมอบด้วย

### 9.2 วิเคราะห์ด้วยมือ (sort | uniq -c)
คอลัมน์ที่ N ของ CSV ดูได้ด้วย `cut` (คอลัมน์ 4 = `doca_ofed`, 6 = `cx8_fw`, 8 = `gpu_driver`, 12 = `bmc_fw`):
```bash
tail -n +2 cluster_version_report.csv | cut -d, -f4 | sort | uniq -c | sort -rn
```
- `tail -n +2` = ข้ามหัวตาราง, `cut -d, -f4` = เอาคอลัมน์ที่ 4 (คั่นด้วย comma), `sort | uniq -c` = นับเวอร์ชันที่ซ้ำกัน
- หาว่าโหนดไหนมีเวอร์ชันหนึ่งๆ: `grep "<เวอร์ชัน>" cluster_version_report.csv | cut -d, -f1`

### 9.3 เปิดด้วย Excel
ดาวน์โหลดไฟล์ไปเครื่อง Windows/Mac (รันบนเครื่องคุณ ไม่ใช่บนเซิร์ฟเวอร์):
```bash
scp gsops@<ชื่อเครื่อง-Admin>:~/cluster-audit/cluster_version_report.csv .
```
แล้วเปิดใน Excel: **Data → From Text/CSV → File Origin = UTF-8 → Delimiter = Comma** แล้วใช้ Filter / Conditional Formatting หาค่าที่ต่าง

---

## 10. เสริม: BMC / NVSwitch ผ่าน Redfish (Optional)

เวอร์ชันเฟิร์มแวร์ของ **BMC ฉบับเต็ม, NVSwitch, CPLD, GPU baseboard** ฯลฯ ในเซิร์ฟเวอร์ HGX มักดูได้ครบที่สุดผ่าน **Redfish API ของ BMC** (เข้าที่ IP ของ BMC ไม่ใช่ IP ของระบบปฏิบัติการ) ซึ่งสคริปต์หลักไม่ได้ทำให้เพราะต้องใช้ **IP/ชื่อผู้ใช้/รหัสผ่านของ BMC** (แต่ละองค์กรไม่เหมือนกัน)

> **เตือน:** อย่าเก็บรหัสผ่านไว้ในไฟล์สคริปต์ หรือพิมพ์ติดไปกับคำสั่งโดยตรง (จะค้างใน history) — ให้พิมพ์ผ่าน `read -s` ตามด้านล่าง

### 10.1 ทดสอบกับ BMC 1 เครื่อง
```bash
read -r -p "BMC IP: " BMC
read -r -p "BMC user: " BMC_USER
read -r -s -p "BMC password: " BMC_PASS; echo
curl -sk -u "$BMC_USER:$BMC_PASS" "https://$BMC/redfish/v1/UpdateService/FirmwareInventory" | jq -r '.Members[]."@odata.id"'
```
จะได้รายการ URL ของเฟิร์มแวร์แต่ละชิ้น (`-k` = ข้ามการตรวจใบรับรอง เพราะ BMC มักใช้ใบรับรองที่เซ็นเอง; ใช้เฉพาะในเครือข่ายจัดการภายในที่เชื่อถือได้)

### 10.2 ดึงเวอร์ชันของทุกชิ้นในรอบเดียว
```bash
for u in $(curl -sk -u "$BMC_USER:$BMC_PASS" "https://$BMC/redfish/v1/UpdateService/FirmwareInventory" | jq -r '.Members[]."@odata.id"'); do
  curl -sk -u "$BMC_USER:$BMC_PASS" "https://$BMC$u" | jq -r '[.Id, .Version] | @tsv'
done
```
ผลตัวอย่าง (ชื่อ `Id` ขึ้นกับผู้ผลิตเซิร์ฟเวอร์ — บนแพลตฟอร์ม HGX มักเห็นรูปแบบ `HGX_FW_BMC_0`, `HGX_FW_GPU_0` … `HGX_FW_NVSwitch_0` …, `HGX_FW_CPLD_0`; ถ้าชื่อต่างไปให้ถือตามที่เครื่องคุณแสดง):
```
HGX_FW_BMC_0        xx.xx.xx
HGX_FW_NVSwitch_0   xx.xx.xx
...
```
บันทึกผลเป็นไฟล์เปรียบเทียบข้ามโหนดได้: `... > bmc_<ชื่อโหนด>.tsv` แล้วใช้ `diff bmc_node01.tsv bmc_node02.tsv` เทียบ

### 10.3 ทำซ้ำกับ 48 BMC
ทำได้โดยวนลูปตามรายชื่อ IP ของ BMC (ใช้ชื่อผู้ใช้/รหัสเดียวกันทุกเครื่องเท่านั้น) — หากต้องการ ให้ขอให้เพิ่มสคริปต์นี้เป็นรอบถัดไป
เครื่องมืออื่น: NVIDIA มีเครื่องมือ `nvfwupd` สำหรับอ่าน/อัปเดตเฟิร์มแวร์ HGX ผ่าน BMC (ตรวจเอกสารรุ่นที่ตรงกับ B300 ของคุณ)

### 10.4 InfiniBand Switch (ถ้ามี)
สวิตช์ InfiniBand (เช่น Quantum) เป็นอุปกรณ์แยกต่างหากและมีระบบปฏิบัติการของตัวเอง (เช่น NVOS) — **ไม่ได้อยู่ในการเก็บข้อมูลของโหนด** ให้เข้าไปที่สวิตช์ตามคู่มือผู้ผลิตและดูเวอร์ชันด้วยคำสั่งของมัน (เช่น `nv show system version` บน NVOS — ตรวจสอบกับเอกสารของรุ่นที่ใช้จริง)

---

## 11. การแก้ไขโหนดที่เวอร์ชันไม่ตรง (Remediation)

คู่มือนี้เน้นการ **ตรวจสอบ (audit)** เท่านั้น — การอัปเกรด/ดาวน์เกรดเฟิร์มแวร์มีความเสี่ยง ควรทำตามขั้นตอนนี้:

1. **ยืนยัน golden version** จากเอกสารส่งมอบ/ตารางความเข้ากันได้ (compatibility matrix) ของผู้ผลิต ระหว่าง DOCA-OFED ↔ ConnectX-8 firmware ↔ GPU Driver ↔ Fabric Manager ↔ BMC
2. **ขออนุมัติช่วงเวลา (maintenance window)** และแจ้งผู้ใช้งาน — โหนดต้องถูก drain ออกจากคิวงาน (เช่น Slurm/Kubernetes) ก่อน
3. **ทดลองกับ 1 โหนดก่อน** ตรวจว่างานรันปกติ แล้วค่อยทำที่เหลือเป็นชุดเล็กๆ
4. อัปเดตเฟิร์มแวร์ NIC บางครั้งต้อง **รีเซ็ตเฟิร์มแวร์หรือรีบูต** จึงมีผล — ทำตามขั้นตอนของผู้ผลิตและอย่าตัดไฟระหว่างอัปเดต
5. **รันคู่มือนี้ซ้ำหลังแก้ไข** เพื่อยืนยันว่าทุกโหนดตรงกัน (analyze.sh ต้องขึ้น "ค่าไม่ซ้ำกัน 1 แบบ" ทุกคอลัมน์ที่ควรเหมือนกัน)
6. เก็บรายงานก่อน/หลัง ไว้เป็นหลักฐาน (ตั้งชื่อไฟล์ลงวันที่)

> คู่มือนี้ไม่มีคำสั่งอัปเกรดเฟิร์มแวร์โดยเจตนา เพราะต้องอิงเวอร์ชันและเอกสารของผู้ผลิตของคุณโดยเฉพาะ — หากต้องการ ให้แจ้งเวอร์ชันเป้าหมายแล้วจัดทำขั้นตอนเพิ่ม

---

## 12. แก้ปัญหาที่พบบ่อย (Troubleshooting)

| อาการ | สาเหตุที่เป็นไปได้ | วิธีแก้ |
|---|---|---|
| `Permission denied (publickey,password)` | SSH key ยังไม่ถูกส่งไปโหนดนั้น/ผู้ใช้ผิด | ทำ 4.2 ซ้ำเฉพาะโหนดนั้น ตรวจชื่อผู้ใช้ |
| `Connection timed out` / `No route to host` | เครื่องปิด, เครือข่าย/ไฟร์วอลล์ | `ping <โหนด>`; ตรวจกับทีมเครือข่าย |
| `Could not resolve hostname` | หาชื่อไม่เจอ | ใช้ IP แทนชื่อ หรือเพิ่มใน `/etc/hosts` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | เครื่องถูกติดตั้งใหม่ ทำให้ host key เปลี่ยน | ตรวจว่าเป็นเครื่องจริง แล้ว `ssh-keygen -R <โหนด>` |
| `sudo: a password is required` | ยังไม่ตั้ง NOPASSWD | ทำ 5.2 หรือใช้ `ansible-playbook ... -K` |
| `bash: ./collect_node.sh: Permission denied` | ไฟล์ยังไม่ได้ตั้งสิทธิ์รัน | `chmod +x *.sh` |
| `bad interpreter` / `^M` | ไฟล์มี CRLF จาก Windows | `sed -i 's/\r$//' *.sh` |
| คอลัมน์ `cx8_*` เป็น `N/A`/`0` | ไม่มี `mstflint`/Device ID ไม่ตรง | ทำ 5.3 และตรวจ Device ID ตาม 6.1(ข) แล้วตั้ง `CX_DEVID` |
| `cx8_detail` มี `=ERR` | `mstflint` เปิดอุปกรณ์ไม่ได้ (ไม่ใช่ root, อุปกรณ์ถูกใช้งาน, รุ่นนี้ไม่ใช่ NIC ธรรมดา) | รันมือตาม 6.1(ค) ดูข้อความ error |
| `doca_ofed` = `N/A` | ไม่ได้ติดตั้ง DOCA-OFED หรือ `ofed_info` ไม่อยู่ใน PATH | `command -v ofed_info`; `dpkg -l | grep -i -E 'doca|ofed'` |
| `gpu_*` เป็น `N/A` | ไดรเวอร์ NVIDIA ไม่ทำงาน | `nvidia-smi` มือดู error; `dmesg | grep -i nvrm` |
| `bmc_fw` = `N/A` | โมดูล IPMI ไม่โหลด / ไม่มี BMC ให้ OS เห็น | `sudo ipmitool mc info` ดู error; ใช้ Redfish (หัวข้อ 10) แทน |
| Ansible `UNREACHABLE` | SSH มีปัญหา | ทดสอบ `ssh gsops@<โหนด>` ด้วยมือก่อน |
| Ansible ช้ามาก | `forks` น้อย | ตรวจ `ansible.cfg` ว่ามี `forks = 48` และรันในโฟลเดอร์เดียวกัน |
| `[WARNING]: Ansible is being run in a world writable directory` | โฟลเดอร์มีสิทธิ์เขียนกว้าง ทำให้ Ansible ไม่อ่าน `ansible.cfg` | `chmod 755 ~/cluster-audit` |
| รายงานมีน้อยกว่า 48 บรรทัด | มีโหนดล้มเหลว | ดู `[FAIL]` / PLAY RECAP แล้วแก้รายโหนด |

**ดูรายละเอียด error ของ Ansible:** เพิ่ม `-v` หรือ `-vvv` ต่อท้ายคำสั่ง `ansible-playbook`
**ดู error ของ Bash script:** ดูไฟล์ `audit_<เวลา>/err/<โหนด>.txt`

---

## 13. สรุปข้อผิดพลาดที่พบและแก้ไขจากเอกสารต้นฉบับ (Corrections to the Original)

ได้ตรวจสอบเอกสารต้นฉบับอย่างละเอียดและแก้ไขดังนี้:

| # | ปัญหาในต้นฉบับ | ผลกระทบ | การแก้ในคู่มือนี้ |
|---|---|---|---|
| 1 | ใช้ `mst status` + `/dev/mst/mtXXXX_...` คู่กับ `mstflint` | `mst` อยู่ในชุด MFT (คนละชุดกับ `mstflint`) และต้อง `mst start` ก่อน ไม่งั้นไม่พบอุปกรณ์เลย → ได้ข้อมูลว่าง | ใช้ `lspci` หาที่อยู่ PCI แล้วส่งให้ `mstflint -d <PCI>` โดยตรง |
| 2 | สคริปต์ Bash: `echo -n "]; " done` ขาด `;` ก่อน `done` | **Syntax error** — สคริปต์รันไม่ได้ | ย้ายตรรกะไปไว้ใน `collect_node.sh` ที่ตรวจสอบแล้ว |
| 3 | ขนาน 16 โปรเซสต่างเขียนต่อท้ายไฟล์เดียวกัน (`>>`) | บรรทัดอาจปนกัน/สูญหาย | เก็บเป็นไฟล์ละโหนดก่อน แล้วค่อยรวม |
| 4 | Ansible `lineinfile` + `local_action` เขียนไฟล์เดียวกันจากหลาย fork; `run_once: no` ไม่ช่วย | race condition, บรรทัดตกหล่น; รันซ้ำจะต่อท้ายซ้ำ | เซฟไฟล์ละโหนด + ล้าง `reports/` ทุกครั้ง + รวมตอนท้าย |
| 5 | Ansible `forks` เริ่มต้น = 5 | 48 โหนดช้า (10 รอบ) | `forks = 48` ใน `ansible.cfg` |
| 6 | ไม่ใช้ `sudo` | `mstflint`, `ipmitool`, `dmidecode` ต้องใช้ root → ผลว่าง | รันด้วย `sudo -n` / `become: true` |
| 7 | ssh ไม่มี `BatchMode`/timeout รวม | ถ้า key ใช้ไม่ได้ สคริปต์จะค้างรอรหัสผ่าน | ใส่ `BatchMode=yes`, `ConnectTimeout`, `timeout 180` |
| 8 | ค่าที่มี comma ทำให้ CSV เพี้ยน | คอลัมน์เลื่อน | แปลง comma เป็น `;` และเก็บเป็นบรรทัดเดียวใน `fmt()` |
| 9 | หัวข้อสรุปบอกว่าเก็บ BMC / GPU Driver / NVSwitch แต่ **ไม่มีคำสั่งจริงเลย** | ข้อมูลขาด | เพิ่ม BMC (IPMI), BIOS, GPU Driver, VBIOS, CUDA, Fabric Manager, kernel, OS ใน `collect_node.sh` และเพิ่มหัวข้อ 10 (Redfish สำหรับ BMC/NVSwitch เต็มรูปแบบ) |
| 10 | ไม่มีขั้นตอนเตรียม SSH key, sudo, ติดตั้งเครื่องมือ, การทดสอบ, วิเคราะห์ผลอัตโนมัติ | ผู้ใช้ใหม่ทำตามไม่ได้ | เพิ่มหัวข้อ 1–6, 9, 12 |

**การทดสอบที่ทำแล้ว:** `bash -n` ตรวจไวยากรณ์สคริปต์ทั้งสาม, รัน `collect_node.sh` จริงบน Ubuntu 24.04 (ค่าที่ไม่มีฮาร์ดแวร์ขึ้น `N/A` ตามออกแบบ), ทดสอบตรรกะสรุป firmware ด้วยคำสั่งจำลอง `lspci`/`mstflint`, ทดสอบ `check_versions.sh` กับ ssh จำลอง (รวมกรณีโหนดล้มเหลว), ทดสอบ `analyze.sh` กับข้อมูลจำลอง และรัน Ansible playbook จริงกับ localhost (ผ่าน)
**สิ่งที่ยังไม่ได้ทดสอบ:** การรันบนเซิร์ฟเวอร์ B300 จริง (ไม่มีฮาร์ดแวร์ในสภาพแวดล้อมนี้) — จึงต้องทำหัวข้อ 6 (ทดสอบ 1 โหนด) ก่อนเสมอ โดยเฉพาะ Device ID ของ ConnectX-8 (`1023`) และรูปแบบข้อความเอาต์พุตของ `ofed_info`/`ipmitool` ที่อาจต่างตามเวอร์ชัน

---

## 14. สรุปคำสั่งย่อ (Cheat Sheet)

**วิธี Bash (เร็วที่สุด):**
```bash
cd ~/cluster-audit
chmod +x *.sh
./check_versions.sh hosts.txt
./analyze.sh version_audit_*.csv
```

**วิธี Ansible:**
```bash
cd ~/cluster-audit
ansible all -i inventory.ini -m ping
ansible-playbook -i inventory.ini get_versions.yml
./analyze.sh cluster_version_report.csv
```

**ตรวจ 1 โหนด:**
```bash
ssh gsops@b300-node01 'sudo -n bash -s' < collect_node.sh
```

---

## 15. ภาคผนวก: โค้ดฉบับเต็ม (Appendix: Full Source Files)

> ไฟล์เหล่านี้ทดสอบแล้วตามหัวข้อ 13 — วางลงในโฟลเดอร์ `~/cluster-audit` ตรงตามชื่อไฟล์

### 15.1 `collect_node.sh` (เก็บข้อมูล 1 โหนด — ใช้ทั้งสองวิธี)
```bash
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

# หมายเหตุ: ครอบทั้งหมดไว้ในฟังก์ชัน main เพื่อให้ bash อ่านสคริปต์ครบก่อนรัน
# (กันกรณีรันผ่าน "bash -s" แล้วคำสั่งภายในไปอ่าน stdin ของสคริปต์เสียเอง)
main() {
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
}

main "$@" </dev/null
exit $?
```

### 15.2 `check_versions.sh` (วิธีที่ 2: Bash ขนาน)
```bash
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
```

### 15.3 `analyze.sh` (วิเคราะห์ผล)
```bash
#!/bin/bash
# analyze.sh - วิเคราะห์ไฟล์ CSV: แต่ละคอลัมน์มีกี่เวอร์ชัน และโหนดไหนต่างจากค่าส่วนใหญ่ (outlier)
# วิธีใช้:  ./analyze.sh version_audit_XXXX.csv
CSV="${1:?วิธีใช้: $0 <ไฟล์.csv>}"
[ -f "$CSV" ] || { echo "ไม่พบไฟล์ $CSV"; exit 1; }

awk -F, '
NR==1 { n=NF; for (i=1;i<=NF;i++) h[i]=$i; next }
NF!=n { bad[++nb]=$1; next }
{
    rows++; host[rows]=$1
    for (i=2;i<=n;i++) { v[rows,i]=$i; cnt[i,$i]++ }
}
END {
    printf "จำนวนโหนดที่วิเคราะห์: %d\n", rows
    for (i=2;i<=n;i++) {
        if (h[i]=="cx8_detail") continue
        best=""; bc=0; distinct=0
        for (k in cnt) { split(k,a,SUBSEP); if (a[1]==i) { distinct++; if (cnt[k]>bc) { bc=cnt[k]; best=a[2] } } }
        printf "\n== %s ==  (ค่าไม่ซ้ำกัน %d แบบ)\n", h[i], distinct
        cmd="sort -rn"
        for (k in cnt) { split(k,a,SUBSEP); if (a[1]==i) printf "%5d  %s\n", cnt[k], a[2] | cmd }
        close(cmd)
        if (distinct>1) {
            printf "  >> ค่าส่วนใหญ่: %s\n", best
            for (r=1;r<=rows;r++) if (v[r,i]!=best) printf "  >> OUTLIER  %-20s %s\n", host[r], v[r,i]
        }
    }
    if (nb>0) { printf "\nบรรทัดที่รูปแบบผิด (จำนวนคอลัมน์ไม่ตรง):"; for (j=1;j<=nb;j++) printf " %s", bad[j]; printf "\n" }
}' "$CSV"
```

### 15.4 `ansible.cfg` (วิธีที่ 1)
```ini
[defaults]
inventory = ./inventory.ini
remote_user = gsops
forks = 48
host_key_checking = False
timeout = 30
retry_files_enabled = False

[privilege_escalation]
become = False
```

### 15.5 `get_versions.yml` (วิธีที่ 1: Playbook)
```yaml
---
# เล่นที่ 1: เตรียมโฟลเดอร์เก็บผลบนเครื่อง Admin (ล้างผลเก่าทิ้งก่อน)
- name: Prepare local report directory
  hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - name: Remove old per-host reports
      ansible.builtin.file:
        path: "{{ playbook_dir }}/reports"
        state: absent
    - name: Create report directory
      ansible.builtin.file:
        path: "{{ playbook_dir }}/reports"
        state: directory
        mode: "0755"

# เล่นที่ 2: เก็บข้อมูลจากทุกโหนดแล้วเซฟเป็นไฟล์ละโหนด (กัน race condition ตอนเขียนไฟล์พร้อมกัน)
- name: Collect versions from all nodes
  hosts: all
  gather_facts: false
  become: true            # ใช้ sudo บนโหนดปลายทาง (ต้องมี sudo ไม่ถามรหัส หรือใช้ -K)
  tasks:
    - name: Run collect_node.sh on the node
      ansible.builtin.script: "{{ playbook_dir }}/collect_node.sh"
      register: collect
      changed_when: false

    - name: Save one CSV line per host on the admin machine
      ansible.builtin.copy:
        content: "{{ collect.stdout | trim }}\n"
        dest: "{{ playbook_dir }}/reports/{{ inventory_hostname }}.csv"
        mode: "0644"
      delegate_to: localhost
      become: false

# เล่นที่ 3: รวมไฟล์เป็นรายงานเดียว
- name: Merge into cluster_version_report.csv
  hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - name: Build merged report
      ansible.builtin.shell: |
        set -e
        { ./collect_node.sh --header; cat reports/*.csv | sort; } > cluster_version_report.csv
      args:
        chdir: "{{ playbook_dir }}"
        executable: /bin/bash
      changed_when: true

    - name: Show how many nodes were collected
      ansible.builtin.shell: "tail -n +2 cluster_version_report.csv | wc -l"
      args:
        chdir: "{{ playbook_dir }}"
      register: nodecount
      changed_when: false

    - name: Report
      ansible.builtin.debug:
        msg: "เก็บข้อมูลได้ {{ nodecount.stdout }} โหนด -> {{ playbook_dir }}/cluster_version_report.csv"
```

### 15.6 `inventory.ini` และ `hosts.txt`
`inventory.ini`
```ini
[b300]
b300-node[01:48]
```
`hosts.txt`
```
# รายชื่อโหนด 1 บรรทัดต่อ 1 เครื่อง (ใส่ hostname หรือ IP) บรรทัดที่ขึ้นต้นด้วย # คือหมายเหตุ
b300-node01
b300-node02
b300-node03
# ... ไปจนถึง b300-node48
```
