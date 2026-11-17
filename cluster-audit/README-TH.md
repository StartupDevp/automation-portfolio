# คู่มือเก็บและตรวจสอบเวอร์ชัน Driver / Firmware ของ NVIDIA B300 (48 โหนด)
**Cluster Version Audit Guide**

## 1. บทนำและวิธีที่เลือกใช้

### 1.1 เป้าหมาย
เก็บข้อมูลเวอร์ชัน Driver และ Firmware ของเซิร์ฟเวอร์ NVIDIA B300 ทั้ง 48 เครื่องให้ **ครบถ้วนและถูกต้อง** แล้วนำมาตรวจสอบว่าเครื่องไหนมีเวอร์ชันไม่ตรงกับเครื่องอื่น

หลักการทำงานของคู่มือนี้คือ **"ทดสอบ 1 เครื่องให้ผ่านก่อน แล้วค่อยเก็บทั้ง 48 เครื่อง"**

### 1.2 วิธีที่เลือก (วิธีเดียว): สคริปต์ `audit.sh` ผ่าน SSH + Redfish
คู่มือนี้เลือกวิธีเดียวที่ดีที่สุดสำหรับงานนี้ คือ **สคริปต์ Bash ชื่อ `audit.sh` ที่รันจากเครื่อง Admin เครื่องเดียว** โดยเก็บข้อมูลจาก 2 แหล่งพร้อมกัน:

| แหล่งข้อมูล | เก็บผ่านอะไร | ได้ข้อมูลอะไร |
|---|---|---|
| **ระบบปฏิบัติการ (Ubuntu) ของแต่ละโหนด** | SSH เข้าโหนด แล้วรันสคริปต์ด้วย sudo | DOCA-OFED, เฟิร์มแวร์ ConnectX-8 ทุกการ์ด, GPU Driver, VBIOS, CUDA, Fabric Manager, BMC (ย่อ), BIOS, kernel, OS และผลคำสั่งดิบทั้งหมดเก็บเป็นหลักฐาน |
| **BMC ของแต่ละโหนด** | Redfish API (HTTPS) จากเครื่อง Admin | เฟิร์มแวร์ทุกชิ้นที่ BMC รายงาน เช่น BMC, BIOS, CPLD, GPU baseboard, NVSwitch |

**เหตุผลที่เลือกวิธีนี้:**
- **ไม่ต้องติดตั้งโปรแกรมใดๆ เพิ่มบนโหนด** (ใช้เฉพาะ SSH และเครื่องมือที่มีอยู่แล้ว)
- ใช้คำสั่งเดียวสำหรับทดสอบ (`./audit.sh test`) และอีกคำสั่งสำหรับทั้ง 48 เครื่อง (`./audit.sh all`)
- เก็บได้ครบทั้งฝั่ง OS และฝั่ง BMC/NVSwitch ซึ่งดูจากใน OS อย่างเดียวไม่ครบ
- เก็บ **หลักฐานดิบ** ทุกเครื่อง จึงตรวจสอบย้อนหลังและวิเคราะห์ละเอียดได้
- **อ่านอย่างเดียว (read-only)** ไม่แก้ไขหรืออัปเกรดอะไรบนเครื่อง (ข้อยกเว้นเดียว: โหลดโมดูล kernel IPMI เพื่ออ่านข้อมูล BMC)
- ไม่ต้องเรียนรู้เครื่องมือใหม่ (เช่น Ansible) ซึ่งเหมาะกับผู้ที่ยังไม่คุ้นเคย Linux

### 1.3 ภาพรวมขั้นตอน

| ช่วง | ทำอะไร | ผลที่ต้องได้ก่อนไปต่อ |
|---|---|---|
| ช่วงที่ 1 | เตรียมเครื่อง Admin และไฟล์สคริปต์ | พิมพ์ `./audit.sh` แล้วขึ้นวิธีใช้ |
| ช่วงที่ 2 | เตรียม **โหนดทดสอบ 1 เครื่อง** (SSH, sudo, เครื่องมือ, BMC) | เข้าโหนดด้วย SSH ได้โดยไม่ถามรหัส |
| ช่วงที่ 3 | **ทดสอบ 1 เครื่อง** ด้วย `./audit.sh test` | ผ่านเกณฑ์ในหัวข้อ 6.4 ครบทุกข้อ |
| ช่วงที่ 4 | เตรียมอีก 47 เครื่อง แล้วเก็บทั้งหมดด้วย `./audit.sh all` | ได้โฟลเดอร์ผลลัพธ์ครบ 48 เครื่อง |
| ช่วงที่ 5 | วิเคราะห์ผล และส่งผลมาให้ตรวจสอบต่อ | รู้ว่าเครื่องไหนเวอร์ชันไม่ตรง |

> **หมายเหตุ:** ถ้าขณะนี้เข้าเซิร์ฟเวอร์หรือ BMC ไม่ได้ ต้องแก้เรื่องการเชื่อมต่อเครือข่ายก่อน (ดูหัวข้อ 5.1 และ 11) เพราะสคริปต์ต้องเชื่อมต่อได้จึงจะเก็บข้อมูลได้

---

## 2. สิ่งที่ต้องเตรียมก่อนเริ่ม (Checklist)

| # | รายการ | ตัวอย่าง | เตรียมแล้ว |
|---|---|---|---|
| 1 | เครื่อง Admin เป็น Ubuntu (22.04 หรือ 24.04) ที่เข้าถึงเครือข่ายของโหนดและเครือข่ายจัดการ (BMC) ได้ | `admin01` | ☐ |
| 2 | ชื่อหรือ IP ของโหนดทั้ง 48 เครื่อง | `b300-node01` … `b300-node48` | ☐ |
| 3 | ชื่อผู้ใช้บนโหนดที่ใช้ SSH และใช้ sudo ได้ | `gsops` | ☐ |
| 4 | IP ของ BMC ของทุกโหนด | `10.10.10.101` … | ☐ |
| 5 | ชื่อผู้ใช้และรหัสผ่าน BMC (แนะนำบัญชีสิทธิ์อ่านอย่างเดียว ถ้ามี) | — | ☐ |
| 6 | ได้รับอนุญาตจากผู้ดูแลระบบให้รันการตรวจสอบนี้ | — | ☐ |
| 7 | อินเทอร์เน็ตหรือ apt mirror ภายใน (เพื่อติดตั้ง `jq`, `mstflint`, `ipmitool`) | — | ☐ |

---

## 3. พื้นฐาน Linux ที่ต้องรู้

### 3.1 Terminal
Terminal คือหน้าจอพิมพ์คำสั่ง (เปิดบน Ubuntu ด้วย `Ctrl + Alt + T` หรือเข้าผ่าน SSH/PuTTY) บรรทัดที่เห็นจะหน้าตาประมาณ `gsops@admin01:~$`
- **ไม่ต้องพิมพ์เครื่องหมาย `$`** พิมพ์เฉพาะคำสั่งแล้วกด `Enter`
- วางข้อความ: `Ctrl + Shift + V` (ไม่ใช่ Ctrl+V) / ยกเลิกคำสั่งที่กำลังรัน: `Ctrl + C`
- Linux แยกตัวพิมพ์เล็ก/ใหญ่ และเว้นวรรคมีความหมาย
- ข้อความใน `<...>` ให้แทนที่ด้วยค่าจริง (ไม่ต้องพิมพ์เครื่องหมาย `<` `>`)

### 3.2 คำสั่งที่ใช้ในคู่มือนี้

| คำสั่ง | ทำอะไร |
|---|---|
| `pwd` | แสดงโฟลเดอร์ปัจจุบัน |
| `ls -l` | แสดงรายการไฟล์ |
| `cd โฟลเดอร์` | เข้าไปในโฟลเดอร์ |
| `mkdir โฟลเดอร์` | สร้างโฟลเดอร์ |
| `cat ไฟล์` | แสดงเนื้อหาไฟล์ |
| `less ไฟล์` | เปิดอ่านไฟล์ยาวทีละหน้า (กด `q` เพื่อออก, `/คำค้น` เพื่อค้นหา) |
| `nano ไฟล์` | แก้ไขไฟล์ (บันทึก `Ctrl+O` แล้ว `Enter`, ออก `Ctrl+X`) |
| `chmod +x ไฟล์` | ทำให้ไฟล์รันเป็นโปรแกรมได้ |
| `./ชื่อไฟล์` | รันสคริปต์ในโฟลเดอร์ปัจจุบัน |
| `sudo คำสั่ง` | รันด้วยสิทธิ์ผู้ดูแล (จะถามรหัสผ่านของคุณ) |
| `ssh user@host` | เข้าไปควบคุมเครื่องอื่น (พิมพ์ `exit` เพื่อออก) |
| `Tab` | เติมชื่อไฟล์อัตโนมัติ / `↑` เรียกคำสั่งก่อนหน้า |

---

## 4. ช่วงที่ 1: เตรียมเครื่อง Admin

### 4.1 ติดตั้งโปรแกรมที่ต้องใช้
```bash
sudo apt update
sudo apt install -y openssh-client jq curl gawk coreutils
```
(`sudo` จะถามรหัสผ่านของคุณ พิมพ์แล้วไม่ขึ้นตัวอักษรเป็นเรื่องปกติ)

ตรวจว่าติดตั้งแล้ว:
```bash
jq --version
curl --version | head -n 1
```

### 4.2 สร้างโฟลเดอร์และไฟล์สคริปต์
```bash
mkdir -p ~/cluster-audit
cd ~/cluster-audit
```
สร้างไฟล์ต่อไปนี้ในโฟลเดอร์นี้ (เนื้อหาเต็มอยู่ในภาคผนวกหัวข้อ 13 วางด้วย `nano ชื่อไฟล์`):

| ไฟล์ | หน้าที่ |
|---|---|
| `audit.sh` | สคริปต์หลักที่คุณสั่งรัน |
| `collect_node.sh` | เก็บสรุปเวอร์ชันของ 1 โหนด |
| `collect_raw.sh` | เก็บหลักฐานดิบของ 1 โหนด |
| `collect_bmc.sh` | เก็บเฟิร์มแวร์จาก BMC ผ่าน Redfish |
| `analyze.sh` | วิเคราะห์หาโหนดที่เวอร์ชันต่างจากส่วนใหญ่ |

ตัวอย่าง:
```bash
nano audit.sh
```
วางเนื้อหา → `Ctrl+O` → `Enter` → `Ctrl+X` ทำซ้ำกับอีก 4 ไฟล์ แล้วตั้งสิทธิ์รัน:
```bash
chmod +x audit.sh collect_node.sh collect_raw.sh collect_bmc.sh analyze.sh
ls -l
```
ไฟล์ทั้ง 5 ควรมีตัว `x` ในสิทธิ์ เช่น `-rwxr-xr-x`

> **ถ้าคัดลอกจาก Windows** แล้วรันไม่ได้ (ขึ้น `bad interpreter` หรือ `^M`) ให้แก้ด้วย:
> ```bash
> sed -i 's/\r$//' *.sh
> ```

### 4.3 ตรวจว่าพร้อม
```bash
for f in *.sh; do bash -n "$f" && echo "OK  $f"; done
./audit.sh
```
- บรรทัดแรกต้องขึ้น `OK` ครบ 5 ไฟล์
- `./audit.sh` เฉยๆ จะแสดงวิธีใช้ (`test` และ `all`) แปลว่าพร้อมแล้ว

---

## 5. ช่วงที่ 2: เตรียมโหนดทดสอบ 1 เครื่อง

เลือกโหนดมา 1 เครื่อง (เช่น `b300-node01`) และ IP BMC ของเครื่องนั้น ในตัวอย่างต่อไปนี้ใช้ `b300-node01` และ `10.10.10.101` ให้แทนด้วยค่าจริงของคุณ

### 5.1 ตรวจการเชื่อมต่อเครือข่าย
```bash
ping -c 3 b300-node01
ping -c 3 10.10.10.101
```
- ต้องขึ้น `0% packet loss` ทั้งสองคำสั่ง
- ถ้า `ping` ไม่ผ่าน = ยังเชื่อมต่อไม่ได้ ให้แก้เรื่องเครือข่าย/เครื่องปิดอยู่ก่อน (หัวข้อ 11)
- (บางเครือข่ายปิด ping ไว้ ให้ลองข้ามไปทดสอบ SSH ใน 5.2 แทน)

### 5.2 ตั้ง SSH แบบไม่ต้องใช้รหัสผ่าน
สคริปต์ต้องเข้าโหนดอัตโนมัติ จึงต้องใช้ SSH key **(ถ้าองค์กรตั้ง key ให้ผู้ใช้ `gsops` ไว้แล้ว ให้ข้ามไปทดสอบที่ท้ายหัวข้อนี้)**

ตรวจว่ามี key หรือยัง:
```bash
ls ~/.ssh/id_ed25519.pub
```
ถ้าขึ้น `No such file` ให้สร้าง (กด `Enter` ตามคำถามทั้งหมดเพื่อใช้ค่าเริ่มต้น):
```bash
ssh-keygen -t ed25519 -C "cluster-audit"
```
ส่ง key ไปยังโหนดทดสอบ (จะถามรหัสผ่านของ `gsops` หนึ่งครั้ง):
```bash
ssh-copy-id gsops@b300-node01
```
ทดสอบ (ต้องขึ้นชื่อเครื่องโดยไม่ถามรหัสผ่าน):
```bash
ssh -o BatchMode=yes gsops@b300-node01 hostname
```
> ถ้าตั้ง passphrase ให้ key ต้องโหลดเข้า ssh-agent ก่อน: `eval "$(ssh-agent -s)"` แล้ว `ssh-add ~/.ssh/id_ed25519`

### 5.3 ตั้ง sudo แบบไม่ถามรหัสผ่าน บนโหนด
คำสั่งอ่านเฟิร์มแวร์ (`mstflint`, `ipmitool`, `dmidecode`) ต้องใช้สิทธิ์ root สคริปต์เรียก `sudo` โดยไม่มีคนพิมพ์รหัสผ่าน

เช็กก่อน:
```bash
ssh gsops@b300-node01 'sudo -n true && echo SUDO_OK || echo SUDO_ต้องการรหัสผ่าน'
```
- ขึ้น `SUDO_OK` = พร้อมแล้ว ข้ามไป 5.4
- ถ้าไม่ผ่าน (ต้องได้รับอนุญาตจากผู้ดูแลระบบ/นโยบายความปลอดภัยก่อน) เข้าโหนด:
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
`visudo -cf` ต้องขึ้น `parsed OK` ถ้าไม่ OK ให้ลบไฟล์ด้วย `sudo rm /etc/sudoers.d/90-gsops-audit` ทันที (ไม่งั้นอาจล็อกตัวเองออกจาก sudo)

### 5.4 ติดตั้งเครื่องมือบนโหนด (ถ้ายังไม่มี)
```bash
ssh gsops@b300-node01 'for c in lspci ofed_info mstflint nvidia-smi ipmitool dmidecode; do printf "%-12s " $c; (export PATH=$PATH:/usr/sbin:/sbin; command -v $c) || echo "ไม่พบ"; done'
```
- `ofed_info` มากับ DOCA-OFED และ `nvidia-smi` มากับ GPU Driver (ถ้าไม่พบ แปลว่าชุดนั้นยังไม่ได้ติดตั้งบนเครื่องนั้น ซึ่งเป็นข้อมูลสำคัญที่ควรบันทึก)
- ถ้า `mstflint`, `ipmitool`, `lspci`, `dmidecode` ไม่พบ ให้ติดตั้ง:
```bash
ssh -t gsops@b300-node01 'sudo apt-get install -y mstflint ipmitool pciutils dmidecode'
```

### 5.5 ตรวจ BMC
```bash
curl -sk -m 10 -o /dev/null -w 'HTTP %{http_code}\n' https://10.10.10.101/redfish/v1/
```
ต้องขึ้น `HTTP 200` หรือ `HTTP 401` (401 = BMC ตอบแล้ว แต่ต้องใช้รหัสผ่าน ซึ่งปกติ) ถ้าขึ้น `HTTP 000` = เข้าถึง BMC ไม่ได้ (เครือข่าย/IP/ไฟร์วอลล์ผิด)

---

## 6. ช่วงที่ 3: ทดสอบ 1 เครื่อง

### 6.1 รันการทดสอบ
```bash
cd ~/cluster-audit
./audit.sh test b300-node01 10.10.10.101
```
- สคริปต์จะถาม `BMC username` และ `BMC password` (รหัสผ่านพิมพ์แล้วไม่ขึ้นตัวอักษร) รหัสผ่านใช้ชั่วคราวเท่านั้น **ไม่ถูกบันทึกลงไฟล์ผลลัพธ์**
- ใช้เวลาประมาณ 1–3 นาที

### 6.2 สคริปต์ทำอะไรบ้าง (5 ส่วน)
1. **ตรวจความพร้อม:** SSH เข้าได้, sudo ไม่ถามรหัส, เครื่องมือบนโหนดครบ, BMC ตอบ Redfish
2. **เก็บข้อมูล:** สรุปเวอร์ชัน + หลักฐานดิบ + เฟิร์มแวร์จาก BMC
3. **แสดงผลสรุปของโหนด:** เป็นรายการ `ชื่อ : ค่า` และบอกว่าคอลัมน์ไหนเก็บไม่ได้ (`N/A`)
4. **แสดงเฟิร์มแวร์จาก BMC:** ตาราง Id / Version / Name
5. **แสดงรายการหลักฐานดิบ**

### 6.3 ตัวอย่างผลที่ได้ (ค่าเป็นตัวอย่างเท่านั้น)
```
=== ทดสอบโหนด: b300-node01 (BMC: 10.10.10.101) ===
--- 1) ตรวจความพร้อม ---
  [PASS] SSH เข้าได้ (ชื่อเครื่อง: b300-node01)
  [PASS] sudo แบบไม่ถามรหัส ใช้ได้
  [PASS] เครื่องมือบนโหนดครบ (lspci ofed_info mstflint nvidia-smi ipmitool dmidecode)
  [PASS] BMC 10.10.10.101 ตอบกลับ Redfish (HTTP 401)
--- 3) ผลสรุปของโหนดนี้ ---
  host             : b300-node01
  os               : Ubuntu 24.04.x LTS
  kernel           : 6.x.x-xx-generic
  doca_ofed        : (เวอร์ชัน DOCA-OFED)
  cx8_count        : 8
  cx8_fw           : 40.xx.xxxxx8     <- เวอร์ชัน x จำนวนการ์ด 8 ใบ
  gpu_count        : 8
  gpu_driver       : xxx.xx.xx
  ...
  >> ไม่มีคอลัมน์ N/A
--- 4) เฟิร์มแวร์จาก BMC (Redfish) ---
  HGX_FW_BMC_0         xx.xx.xx      ...
  HGX_FW_NVSwitch_0    xx.xx.xx      ...
```

### 6.4 เกณฑ์ผ่านการทดสอบ (ต้องผ่านครบทุกข้อก่อนไปช่วงที่ 4)

| # | เกณฑ์ | วิธีตรวจ | ผล |
|---|---|---|---|
| 1 | ตรวจความพร้อมขึ้น `[PASS]` ครบ ไม่มี `[FAIL]` | ดูส่วน 1) | ☐ |
| 2 | `doca_ofed` มีค่า (ไม่ใช่ N/A) | ดูส่วน 3) | ☐ |
| 3 | `cx8_count` ตรงกับจำนวนการ์ด ConnectX-8 จริงของเครื่องรุ่นนี้ (เช่น 8) และ `cx8_fw` มีเวอร์ชันเดียว | เทียบกับคู่มือฮาร์ดแวร์ / `lspci` | ☐ |
| 4 | `gpu_count` เท่ากับจำนวน GPU จริง (เช่น 8) และ `gpu_driver`, `gpu_vbios`, `cuda` มีค่า | เทียบ `nvidia-smi` | ☐ |
| 5 | `fabricmanager` มีค่า และเวอร์ชันสอดคล้องกับ `gpu_driver` | ดูส่วน 3) | ☐ |
| 6 | `bmc_fw` และ `bios` มีค่า | ดูส่วน 3) | ☐ |
| 7 | ตาราง BMC (ส่วน 4) มีเฟิร์มแวร์ของ BMC, GPU และ NVSwitch ครบตามที่คาดหวัง | ดูส่วน 4) | ☐ |
| 8 | ไฟล์ `raw.txt` มีครบ 20 หัวข้อ และไม่ถูกตัดกลางคัน | ดูส่วน 5) | ☐ |
| 9 | ค่าที่สคริปต์เก็บ **ตรงกับค่าที่รันมือบนเครื่องจริง** (ดู 6.5) | เปรียบเทียบ | ☐ |

### 6.5 ตรวจสอบความถูกต้องด้วยมือ (สำคัญ)
เพื่อยืนยันว่าสคริปต์เก็บค่าถูกต้อง ให้เข้าโหนดทดสอบ แล้วรันคำสั่งเหล่านี้เทียบกับผลของสคริปต์:
```bash
ssh gsops@b300-node01
```
บนโหนด:
```bash
ofed_info -s                                         # เทียบกับ doca_ofed
lspci -nn | grep -i mellanox                         # ดูจำนวนการ์ด และรหัสรุ่น [15b3:xxxx]
sudo mstflint -d <ที่อยู่ PCI เช่น 0000:18:00.0> q   # เทียบ FW Version กับ cx8_fw / cx8_detail
nvidia-smi --query-gpu=index,driver_version,vbios_version --format=csv
dpkg-query -W 'nvidia-fabricmanager*'                # เทียบกับ fabricmanager
sudo ipmitool mc info | grep -i 'Firmware Revision'  # เทียบกับ bmc_fw
sudo dmidecode -s bios-version                       # เทียบกับ bios
exit
```
ค่าต้องตรงกัน ถ้าไม่ตรง **ห้ามไปต่อ** ให้ส่งผลมาตรวจสอบ (หัวข้อ 10)

### 6.6 รหัสรุ่น (Device ID) ของ ConnectX-8
สคริปต์ตั้งค่าเริ่มต้นว่า ConnectX-8 มี PCI Device ID `1023` ถ้า `cx8_count` เป็น `0` ทั้งที่เครื่องมีการ์ด ให้ดูรหัสรุ่นจริง:
```bash
ssh gsops@b300-node01 'lspci -nn | grep -i mellanox'
```
หาบรรทัดที่เป็น ConnectX-8 แล้วดูตัวเลขใน `[15b3:XXXX]` จากนั้นรันทดสอบใหม่โดยระบุรหัส:
```bash
CX_DEVID=XXXX ./audit.sh test b300-node01 10.10.10.101
```
(ถ้าต้องใช้ค่านี้ตลอด ให้แก้บรรทัด `CX_DEVID="${CX_DEVID:-1023}"` ในไฟล์ `collect_node.sh`)

> หมายเหตุ: คอลัมน์ `cx8_fw` ใช้รหัสรุ่นนี้ แต่ไฟล์หลักฐานดิบ `raw.txt` เก็บ `mstflint q` ของ **การ์ด NVIDIA/Mellanox ทุกใบ** (15b3) ไว้ด้วย จึงตรวจสอบย้อนหลังได้เสมอ

### 6.7 ถ้าบางคอลัมน์เป็น N/A
| คอลัมน์ | สาเหตุที่เป็นไปได้ | วิธีแก้ |
|---|---|---|
| `doca_ofed` | ยังไม่ได้ติดตั้ง DOCA-OFED / ไม่พบ `ofed_info` | `ssh gsops@node 'dpkg -l \| grep -i -E "doca\|ofed"'` |
| `cx8_*` | ไม่มี `mstflint` / Device ID ไม่ตรง | ติดตั้ง `mstflint` (5.4) และตั้ง `CX_DEVID` (6.6) |
| `gpu_*`, `cuda` | GPU Driver ไม่ทำงาน | บนโหนดรัน `nvidia-smi` ดู error |
| `fabricmanager` | ไม่ได้ติดตั้งแพ็กเกจ `nvidia-fabricmanager` | ตรวจ `dpkg -l \| grep fabric` |
| `bmc_fw` | โมดูล IPMI ไม่ทำงาน / OS มองไม่เห็น BMC | `sudo ipmitool mc info` ดู error (ข้อมูล BMC เต็มรูปแบบดูจาก Redfish อยู่แล้ว) |
| `bios` | ไม่มี `dmidecode` | ติดตั้ง `dmidecode` |

### 6.8 ถ้าไม่มีข้อมูลจาก BMC
| อาการ | วิธีแก้ |
|---|---|
| `ERROR: อ่าน FirmwareInventory ... ไม่ได้` พร้อมข้อความ error ของ BMC | ตรวจชื่อผู้ใช้/รหัสผ่าน BMC และสิทธิ์ของบัญชี |
| `BMC ... ไม่ตอบ Redfish (HTTP 000)` | ตรวจ IP, เครือข่ายจัดการ, ไฟร์วอลล์ (พอร์ต 443) |
| BMC ตอบ แต่ไม่มีรายการ NVSwitch/GPU | เครื่องรุ่นนี้อาจใช้พาธ Redfish คนละแบบ ให้ส่งไฟล์ `bmc/<โหนด>.tsv` มาตรวจสอบ (หัวข้อ 10) |

เมื่อแก้แล้วให้รัน `./audit.sh test ...` ใหม่จนผ่านครบตาม 6.4

---

## 7. ช่วงที่ 4: เก็บข้อมูลทั้ง 48 เครื่อง

**ทำช่วงนี้เมื่อผ่านเกณฑ์ 6.4 ครบแล้วเท่านั้น**

### 7.1 สร้างรายชื่อโหนด `hosts.txt`
ถ้าชื่อเรียงเลขต่อเนื่อง (ปรับชื่อให้ตรงกับของจริง):
```bash
cd ~/cluster-audit
for i in $(seq -w 1 48); do echo "b300-node$i"; done > hosts.txt
wc -l hosts.txt
```
`wc -l` ต้องขึ้น `48 hosts.txt` (ถ้าชื่อไม่เรียงเลข ให้พิมพ์เองด้วย `nano hosts.txt` บรรทัดละ 1 โหนด; บรรทัดขึ้นต้นด้วย `#` คือหมายเหตุ)

### 7.2 สร้างรายการ IP ของ BMC `bmc.txt`
รูปแบบ: `ชื่อโหนด  IP-BMC` (คั่นด้วยช่องว่าง) บรรทัดละ 1 โหนด
```bash
nano bmc.txt
```
ตัวอย่าง:
```
b300-node01 10.10.10.101
b300-node02 10.10.10.102
```
- **ชื่อโหนดใน `bmc.txt` ต้องตรงกับใน `hosts.txt` ทุกตัวอักษร**
- ถ้า BMC ทุกเครื่องใช้ชื่อผู้ใช้/รหัสผ่านเดียวกัน สคริปต์จะถามครั้งเดียว ถ้าไม่เหมือนกัน ให้แยกรันเป็นกลุ่มที่ใช้รหัสเดียวกัน (ทำ `hosts_กลุ่ม.txt` / `bmc_กลุ่ม.txt` แล้วรัน `./audit.sh all hosts_กลุ่ม.txt bmc_กลุ่ม.txt`)
- ถ้าไม่มีไฟล์ `bmc.txt` สคริปต์จะข้ามการเก็บข้อมูลจาก BMC

### 7.3 เตรียมอีก 47 เครื่อง (ทำเหมือนที่ทำกับโหนดทดสอบ)

**(ก) ส่ง SSH key ไปทุกโหนด** (ถามรหัสผ่านของ `gsops` ทีละเครื่อง ทำครั้งเดียว):
```bash
for h in $(grep -v '^#' hosts.txt | sed '/^$/d'); do
  echo "=== $h ==="
  ssh-copy-id -o StrictHostKeyChecking=accept-new gsops@"$h"
done
```

**(ข) ตั้ง sudo ไม่ถามรหัสผ่านบนทุกโหนด** (ถ้ายังไม่มี ทำตามหัวข้อ 5.3 ทีละเครื่อง หรือใช้เครื่องมือจัดการของทีมคุณ) แล้วตรวจ:
```bash
for h in $(grep -v '^#' hosts.txt | sed '/^$/d'); do
  printf '%-20s ' "$h"
  ssh -o BatchMode=yes -o ConnectTimeout=5 gsops@"$h" 'sudo -n true && echo OK' 2>&1 | tail -n 1
done
```
ทุกบรรทัดต้องลงท้ายด้วย `OK` (บรรทัดไหนไม่ใช่ ให้แก้เครื่องนั้นก่อน)

**(ค) ติดตั้งเครื่องมือบนทุกโหนด** (ถ้าทดสอบพบว่าขาด):
```bash
for h in $(grep -v '^#' hosts.txt | sed '/^$/d'); do
  echo "=== $h ==="
  ssh -o BatchMode=yes gsops@"$h" 'sudo -n apt-get install -y mstflint ipmitool pciutils dmidecode' 2>&1 | tail -n 1
done
```

### 7.4 เก็บข้อมูลทั้งหมด
```bash
./audit.sh all hosts.txt bmc.txt
```
- ถามชื่อผู้ใช้/รหัสผ่าน BMC หนึ่งครั้ง
- เก็บพร้อมกันครั้งละ 12 เครื่อง (ปรับได้: `PARALLEL=24 ./audit.sh all hosts.txt bmc.txt`) ลำดับที่แสดงไม่เรียง เป็นเรื่องปกติ
- ผลที่ควรเห็น:
```
b300-node03   summary=OK   raw=OK   bmc=OK
b300-node01   summary=OK   raw=OK   bmc=OK
...
โหนดทั้งหมด: 48 | เก็บ summary สำเร็จ: 48
ผลทั้งหมดอยู่ในโฟลเดอร์: results_20261117_101500
```
- **เกณฑ์สำเร็จ:** `สำเร็จ: 48` และ "โหนดที่มีบางส่วนล้มเหลว" ขึ้น `(ไม่มี)`

### 7.5 รันซ้ำเฉพาะเครื่องที่ล้มเหลว
ดูสาเหตุที่ `results_.../err/<โหนด>.*.txt` แก้ปัญหา แล้วทำรายชื่อเฉพาะโหนดนั้น:
```bash
nano hosts_retry.txt
./audit.sh all hosts_retry.txt bmc.txt
```
จะได้โฟลเดอร์ผลลัพธ์ใหม่ (ผลรอบแรกไม่ถูกลบ) นำผลมาพิจารณาร่วมกัน

---

## 8. ผลลัพธ์ที่ได้และวิธีอ่าน

ทุกครั้งที่รัน จะได้โฟลเดอร์ `results_<วันที่_เวลา>/` (หรือ `results_test_<โหนด>_...` ตอนทดสอบ) ที่มีเนื้อหา:

| ไฟล์/โฟลเดอร์ | เนื้อหา |
|---|---|
| `summary.csv` | ตารางสรุปเวอร์ชันจาก OS ทุกโหนด (1 โหนด = 1 บรรทัด) |
| `bmc_report.csv` | ตารางเฟิร์มแวร์จาก BMC ทุกโหนด (แต่ละคอลัมน์ = เฟิร์มแวร์ 1 ชิ้น) |
| `analysis.txt` | ผลวิเคราะห์อัตโนมัติ: แต่ละคอลัมน์มีกี่เวอร์ชัน และโหนดไหนต่างจากส่วนใหญ่ |
| `raw/<โหนด>/raw.txt` | หลักฐานดิบ ผลคำสั่งเต็มของโหนดนั้น (nvidia-smi -q, mstflint, dmidecode ฯลฯ) |
| `bmc/<โหนด>.tsv` | ผลดิบจาก Redfish ของโหนดนั้น |
| `err/` | ข้อความ error (ถ้ามี) |
| `status/` | สถานะสำเร็จ/ล้มเหลวของแต่ละโหนด |

**ดูผลบนหน้าจอ:**
```bash
cd results_20261117_101500
less analysis.txt
column -s, -t < summary.csv | less -S
grep -n '^#####' raw/b300-node01/raw.txt
```
(ใน `less -S` ใช้ลูกศรซ้าย/ขวาเลื่อนดูคอลัมน์ กด `q` เพื่อออก)

**ดาวน์โหลดไปเปิดใน Excel** (รันบนเครื่อง Windows/Mac ของคุณ):
```bash
scp -r gsops@<ชื่อเครื่อง-Admin>:~/cluster-audit/results_20261117_101500 .
```
เปิด `summary.csv` ใน Excel ด้วย **Data → From Text/CSV → File Origin: UTF-8 → Delimiter: Comma**

---

## 9. การวิเคราะห์ผล

### 9.1 อ่าน `analysis.txt`
ตัวอย่าง:
```
== cx8_fw ==  (ค่าไม่ซ้ำกัน 2 แบบ)
   47  40.xx.xxxxx8
    1  40.yy.yyyyx8
  >> ค่าส่วนใหญ่: 40.xx.xxxxx8
  >> OUTLIER  b300-node17     40.yy.yyyyx8
```
- ตัวเลขหน้าค่า = จำนวนโหนดที่ใช้ค่านั้น
- `ค่าไม่ซ้ำกัน 1 แบบ` = ทุกโหนดตรงกัน (ปกติ)
- `OUTLIER` = โหนดที่ต่างจากค่าส่วนใหญ่ → ต้องตรวจสอบ
- `cx8_fw` ที่เป็น `40.xx.xxxxx7|40.yy.yyyyx1` = ในโหนดเดียวมีการ์ดคนละเวอร์ชันปนกัน (รุนแรงกว่า ควรตรวจก่อน)

### 9.2 สิ่งที่ต้องตรวจ
| คอลัมน์ | ควรเหมือนกันทุกโหนดหรือไม่ | ถ้าไม่เหมือน |
|---|---|---|
| `os`, `kernel` | ควรเหมือน | มีการอัปเดตแพ็กเกจเฉพาะบางเครื่อง |
| `doca_ofed` | ต้องเหมือน | ไดรเวอร์เครือข่ายไม่ตรงกัน เสี่ยงกับงานแบบกระจาย (NCCL/RDMA) |
| `cx8_count` | ต้องเท่ากัน | การ์ดขาด/ไม่ถูกตรวจพบ ตรวจฮาร์ดแวร์ |
| `cx8_fw` | ต้องเหมือน และต้องมีเวอร์ชันเดียวในเครื่อง | เฟิร์มแวร์ NIC ไม่ตรง |
| `gpu_count` | ต้องเท่ากัน (เช่น 8) | GPU หลุด/ไม่ถูกตรวจพบ |
| `gpu_driver`, `cuda` | ต้องเหมือน | Driver ไม่ตรงกัน |
| `gpu_vbios` | ต้องเหมือน | VBIOS ไม่ตรง |
| `fabricmanager` | ต้องเหมือน และสอดคล้องกับ `gpu_driver` | NVSwitch/NVLink อาจทำงานผิดปกติ |
| `bmc_fw`, `bios` | ต้องเหมือน | เฟิร์มแวร์แพลตฟอร์มไม่ตรง |
| คอลัมน์ใน `bmc_report.csv` | ต้องเหมือน | BMC/GPU baseboard/NVSwitch/CPLD ไม่ตรง |

> "ค่าส่วนใหญ่" **ไม่ได้แปลว่าถูกต้องเสมอไป** ต้องเทียบกับเวอร์ชันมาตรฐาน (golden) ที่ผ่านการรับรอง/เอกสารส่งมอบของผู้ผลิตด้วย

### 9.3 ขั้นตอนหลังได้ผล
1. ดู `analysis.txt` จดรายชื่อโหนดที่เป็น OUTLIER และคอลัมน์ที่ต่าง
2. เปิด `raw/<โหนด>/raw.txt` ของโหนดนั้นเพื่อดูหลักฐานเต็ม
3. เทียบกับเวอร์ชัน golden และตารางความเข้ากันได้ (compatibility matrix) ระหว่าง DOCA-OFED ↔ เฟิร์มแวร์ ConnectX-8 ↔ GPU Driver ↔ Fabric Manager ↔ BMC
4. คู่มือนี้ **ไม่มีขั้นตอนอัปเกรดเฟิร์มแวร์** เพราะต้องอิงเวอร์ชันเป้าหมายและเอกสารผู้ผลิต การแก้ไขต้องขออนุมัติช่วงบำรุงรักษา (maintenance window), ถอดเครื่องออกจากคิวงาน (drain) และทดลองกับ 1 เครื่องก่อน
5. หลังแก้ไข ให้รัน `./audit.sh all` ซ้ำเพื่อยืนยัน

### 9.4 แบบบันทึกผลการทดสอบ 1 เครื่อง (กรอกเพื่อเก็บเป็นหลักฐาน)

| รายการ | ค่าที่ได้ | ผ่าน/ไม่ผ่าน |
|---|---|---|
| โหนดทดสอบ / IP BMC | | |
| วันที่ / ผู้ทดสอบ | | |
| ตรวจความพร้อม (SSH/sudo/เครื่องมือ/BMC) | | |
| `doca_ofed` | | |
| `cx8_count` / `cx8_fw` | | |
| `gpu_count` / `gpu_driver` / `gpu_vbios` / `cuda` | | |
| `fabricmanager` | | |
| `bmc_fw` / `bios` | | |
| รายการเฟิร์มแวร์จาก BMC (BMC/GPU/NVSwitch) | | |
| เทียบกับคำสั่งรันมือ (6.5) ตรงกันหรือไม่ | | |
| สรุป: อนุญาตให้เก็บทั้ง 48 เครื่อง | ☐ ใช่ ☐ ไม่ | |

---

## 10. การส่งผลกลับมาเพื่อตรวจสอบและวิเคราะห์ต่อ

**หลังทดสอบ 1 เครื่อง** ส่งสิ่งนี้มาเพื่อตรวจว่าถูกต้องก่อนเก็บทั้ง 48 เครื่อง:
- โฟลเดอร์ `results_test_<โหนด>_...` ทั้งโฟลเดอร์ (หรือบีบอัดด้วย `tar -czf test_result.tar.gz results_test_*`) และข้อความทั้งหมดที่สคริปต์แสดงบนหน้าจอ

**หลังเก็บทั้ง 48 เครื่อง** ส่ง:
- `summary.csv`, `bmc_report.csv`, `analysis.txt`
- `raw/` ของโหนดที่เป็น OUTLIER (และของโหนดปกติ 1 เครื่องไว้เทียบ)

**ข้อควรระวังเรื่องข้อมูล:** ไฟล์ผลลัพธ์มีข้อมูลภายในองค์กร เช่น ชื่อโหนด, Serial/UUID ของ GPU และการ์ด, PSID ของ NIC ควรจัดเป็นข้อมูลภายในและส่งเฉพาะช่องทางที่องค์กรอนุญาต ส่วน **รหัสผ่าน BMC ไม่ถูกบันทึกลงไฟล์ใดๆ**

---

## 11. แก้ปัญหาที่พบบ่อย

| อาการ | สาเหตุที่เป็นไปได้ | วิธีแก้ |
|---|---|---|
| `ping` โหนด/BMC ไม่ผ่าน หรือเข้า SSH/BMC ไม่ได้เลย | เครื่องปิด, สาย/สวิตช์/VLAN, ไฟร์วอลล์, IP เปลี่ยน, เครือข่ายจัดการมีปัญหา | ตรวจเครื่องและเครือข่ายที่หน้างาน/ทีมเครือข่ายก่อน ไม่ใช่ปัญหาของสคริปต์ |
| `Permission denied (publickey,password)` | ยังไม่ได้ส่ง SSH key / ผู้ใช้ผิด | ทำ 5.2 ซ้ำกับโหนดนั้น |
| `Connection timed out` / `No route to host` | เครือข่ายถึงเครื่องไม่ได้ | ตรวจเครือข่าย, `ping` |
| `Could not resolve hostname` | หาชื่อเครื่องไม่เจอ | ใช้ IP แทนชื่อ หรือเพิ่มชื่อใน `/etc/hosts` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | เครื่องถูกติดตั้งใหม่ host key เปลี่ยน | ตรวจว่าเป็นเครื่องจริง แล้ว `ssh-keygen -R <โหนด>` |
| `sudo: a password is required` | ยังไม่ตั้ง NOPASSWD | ทำ 5.3 |
| `Permission denied` เมื่อรัน `./audit.sh` | ยังไม่ได้ตั้งสิทธิ์รัน | `chmod +x *.sh` |
| `bad interpreter` / `^M` | ไฟล์มี CRLF จาก Windows | `sed -i 's/\r$//' *.sh` |
| `jq: command not found` | ยังไม่ได้ติดตั้ง jq | `sudo apt install -y jq` |
| ผล `summary` ขึ้น `FAIL` ตอนรัน `all` | โหนดนั้นเข้าไม่ได้หรือ sudo ไม่ผ่าน | ดูไฟล์ `err/<โหนด>.summary.txt` |
| `bmc=FAIL` | รหัสผ่าน/IP BMC ผิด หรือ BMC ไม่ตอบ | ดูไฟล์ `err/<โหนด>.bmc.txt` |
| `bmc=SKIP` | โหนดนั้นไม่มีใน `bmc.txt` | เพิ่มบรรทัดใน `bmc.txt` (ชื่อต้องตรงกับ `hosts.txt`) |
| คอลัมน์เป็น `N/A` | ไม่มีเครื่องมือ/ไดรเวอร์บนโหนด | ดูตาราง 6.7 |

---

## 12. ความปลอดภัยและข้อจำกัด

**สิ่งที่สคริปต์ทำ/ไม่ทำ**
- **อ่านอย่างเดียว:** ไม่แก้ไข ไม่อัปเกรด ไม่รีสตาร์ต ไม่ลบอะไรบนโหนดหรือ BMC
- สิ่งเดียวที่เปลี่ยนคือ `modprobe ipmi_devintf ipmi_si` เพื่อโหลดโมดูลอ่านข้อมูล BMC (ไม่ส่งผลต่อการทำงานของเครื่อง และหายไปเมื่อรีบูต)
- สคริปต์ส่งตัวเองไปรันผ่าน SSH ไม่ทิ้งไฟล์ไว้บนโหนด
- รหัสผ่าน BMC เก็บในไฟล์ชั่วคราวสิทธิ์ 600 ระหว่างเรียก API แล้วลบทันที ไม่ปรากฏในรายการโปรเซส (`ps`) และไม่อยู่ใน history
- `curl -k` ข้ามการตรวจใบรับรองของ BMC (ใช้ในเครือข่ายจัดการภายในที่เชื่อถือได้เท่านั้น)
- `StrictHostKeyChecking=accept-new` ยอมรับ host key ของเครื่องใหม่ครั้งแรกอัตโนมัติ

**สิ่งที่ผ่านการทดสอบแล้ว (ในสภาพแวดล้อมจำลอง บน Ubuntu 24.04)**
ตรวจไวยากรณ์สคริปต์ทั้งหมด, ทดสอบ `audit.sh test` และ `audit.sh all` กับ ssh/curl/lspci/mstflint จำลอง (รวมกรณีโหนดเข้าไม่ได้, รหัสผ่านที่มีเครื่องหมายพิเศษ, การรวมตาราง BMC, การวิเคราะห์หา OUTLIER)

**สิ่งที่ยังไม่ได้ทดสอบ (ไม่มีฮาร์ดแวร์ B300 จริง)**
รูปแบบผลลัพธ์ที่แท้จริงของ `ofed_info`, `ipmitool`, `nvidia-smi` บนเครื่องของคุณ, Device ID ของ ConnectX-8 (`1023` เป็นค่าตั้งต้น), และชื่อรายการเฟิร์มแวร์ใน Redfish ของ BMC รุ่นที่ใช้ — **จึงต้องทดสอบ 1 เครื่องและส่งผลมาตรวจก่อนเสมอ** ซึ่งเป็นเหตุผลที่คู่มือนี้บังคับขั้นตอนทดสอบก่อนเก็บจริง

---

## 13. ภาคผนวก: ซอร์สโค้ดฉบับเต็ม

> วางลงในโฟลเดอร์ `~/cluster-audit` ตรงตามชื่อไฟล์ (เนื้อหาในไฟล์บางส่วนเป็นภาษาไทยเป็นเรื่องปกติ)

### 13.1 `audit.sh`
```bash
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
```

### 13.2 `collect_node.sh`
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

### 13.3 `collect_raw.sh`
```bash
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
```

### 13.4 `collect_bmc.sh`
```bash
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
```

### 13.5 `analyze.sh`
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
