# Work Plan — 3 active jobs

Detailed plans to keep each job moving without needing a decision every time.
แผนงานละเอียดของ 3 งาน เพื่อให้เดินหน้าต่อได้โดยไม่ต้องรอตัดสินใจทุกครั้ง

Last updated: 2026-09-07

---

## 1. Openclaw — run independently on internal jobs
Root cause of the block: the local 3B model fails on long jobs.

1. Break long jobs into smaller steps — chunk each task so no single step
   exceeds what the 3B model reliably handles.
2. Checkpoint after each chunk, so a failure doesn't lose prior progress.
3. Keep the no-internet rule as-is — no need to revisit it.
4. Test the chunked approach on one small job first, before resuming the
   full CRAB queue.
5. Once stable, resume the queue and let it run unattended on internal
   tasks.

แบ่งงานยาวเป็นชิ้นเล็ก ๆ ให้พอดีกับโมเดล 3B, checkpoint ทุกชิ้นกันงานหาย,
คงกฎห้ามต่อเน็ตไว้เหมือนเดิม, ทดสอบกับงานเล็กก่อนค่อยรันคิวเต็ม

---

## 2. Translation tool — no action needed
Status is fine as-is: review-ready, scheduled task
(Greenstar-Verification-1300, daily 13:00) already registered. Wait for the
evening summary; nothing to push right now.

สถานะปกติดี รอสรุปรอบเย็นตามกำหนด ไม่ต้องดำเนินการอะไรเพิ่มตอนนี้

---

## 3. WebGreenStore — close out remaining work
1. Inventory what's actually left open — pull latest status (Round 5 audit,
   3D renders, `worktree-greenstor-diagram-realism` branch) and list
   remaining unchecked items.
2. Verify renders/diagrams already produced match spec (cable count,
   topology layering) before calling them done.
3. Merge the worktree branch back once verified, instead of leaving it
   open indefinitely.
4. Close out documentation so nothing has to be re-derived later.

เช็คว่างานเหลืออะไรบ้าง, ตรวจ render/diagram ให้ตรง spec ก่อนปิดงาน,
merge worktree branch กลับเมื่อตรวจผ่านแล้ว, ปิดท้ายด้วยเอกสารสรุป

---

## Backup remote access
Tailscale issue today was key expiry (fixed via reconnect + disable key
expiry on MyServ). As a backup path independent of Tailscale, install:
- **AnyDesk** (primary backup — free personal use, unattended access)
- **Chrome Remote Desktop** (secondary backup — simplest, free)

Install both now while local access is available, so they're ready before
the next Tailscale issue.
