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
