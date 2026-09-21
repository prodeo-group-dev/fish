# The Principal

School management product (FiSH+ER) - Nigerian EMIS school-operations layer.

**Path:** `C:\Users\femif\Claude\Projects\FiSH\ER\Principal`

## Docs

| File | Purpose |
|------|---------|
| `docs/The_Principal_SRS.docx` | Source SRS (17 Sep 2026) |
| `docs/The_Principal_SRS.md` | Text extract of the SRS |
| `docs/The_Principal_Backlog.md` | MoSCoW backlog (waves W0-W8) |
| `docs/The_Principal_MVP_Definition.md` | What Pilot (Path-to-1M Phase 1) actually needs vs. the SRS's full Must list; the two real MVP gates (SPI/TPI sign-off, this review's fixes shipping) |
| `docs/ADR-001-SchoolAdmissions-Kotlin-Postgres.md` | Accepted: Kotlin SchoolAdmissions + PostgreSQL SoR |

## Status

- **W0-W6 landed and live in production** (`school-api.theprodeogroup.com`), plus BK-ATT-6 (UC-20 automated attendance capture via BuzzMe/DPID) — see `docs/The_Principal_Backlog.md`'s own status line and change log for the current, authoritative state; this file is an index, not a live status page.
- WEB frontend work (BK-PLT-2's "shared nav chrome" half) handed off to the dedicated `FiSH+ER WEB` thread (2026-09-21) — not tracked in detail here.
- `COORDINATION.md` at `SchoolAdmissions/`'s own root governs cross-thread work on that repo (and the sibling `BuzzMe` repo) - check it before starting non-trivial changes there.
- Code Reviewer: review staged builds (path, SHAs, BK-*) before commit.
- Financial postings: FiSH SOP events only - never direct GL writes.

## Layout

| Path | Role |
|------|------|
| `SchoolAdmissions/` | Kotlin domain/service (W0+W1) |
| `docs/` | SRS, backlog, ADRs |