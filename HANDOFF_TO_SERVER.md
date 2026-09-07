# Handoff: move coordination to the server

Coordination for the 3 jobs below is moving from this cloud window
(`automation-portfolio`, session `session_01DLr7vfWxaNyBLySKgQ5fGm`) to a
Claude Code session running directly on the machine where the real work and
the real `ReportCenter.md` live: `E:\skill-portal` (repo `skill-dev-portal`).

การคุมงานของ 3 งานด้านล่างนี้ ย้ายจากหน้าต่าง cloud นี้ ไปเป็น session Claude Code
ที่รันตรงบนเครื่องที่งานจริงและไฟล์ ReportCenter.md จริงอยู่ (`E:\skill-portal`,
repo `skill-dev-portal`)

## Why
- `ReportCenter.md` that the 3 jobs update lives locally on that machine — it was
  never pushed to GitHub, so this cloud window could only see status summaries,
  not the real file.
- The 3 jobs (Openclaw, WebGreenStore, Translation tool) already run on that
  machine via Claude Code CLI + Remote Control — no new install needed.

## What to do on the server
1. Open PowerShell on that machine (or use the terminal Claude Code CLI is
   already running in).
2. Either resume one of the existing idle sessions there, or start a fresh one
   with `claude`.
3. Paste the seed briefing below as your first message so it picks up the
   coordinator role immediately instead of starting blank.

## Seed briefing to paste into the new/resumed session

```
You are taking over as the coordinator for 3 ongoing jobs on this machine, all
in the skill-dev-portal repo: Openclaw, WebGreenStore, and Translation tool.

Find (or create) ReportCenter.md in this repo's working directory and use it
as the single central status file for all 3 — read each job's own status/worklog
output and keep this file current.

Last known status (from the cloud coordinator, 2026-09-07 ~03:45 UTC):
- Openclaw: blocked — needs a decision: try qwen2.5-coder:3b / break jobs into
  smaller steps / review the no-internet rule / pause.
- WebGreenStore: stopped, review-ready, nothing blocking.
- Translation tool: stopped, review-ready, nothing blocking. A related
  scheduled task "Greenstar-Verification-1300" was registered (daily 13:00,
  auto-expires 2026-10-07).

Confirm you can read the real local ReportCenter.md and summarize its current
contents back to me.
```

## Status of the old cloud coordinator
This `automation-portfolio` window keeps its own `ReportCenter.md` as a
snapshot of the last known state, but is no longer the active coordinator once
the server-side session confirms it's picked up the role.

หน้าต่าง cloud นี้จะเก็บ `ReportCenter.md` ของตัวเองไว้เป็นสถานะล่าสุดที่รู้ แต่จะเลิกทำหน้าที่คุมงานหลัก
เมื่อ session บนเซิร์ฟเวอร์ยืนยันว่ารับช่วงต่อแล้ว
