# Proposal: adopt FR-36's mark-code table shape for BK-ATT-2

**Status:** built and live, 2026-09-22 (`fish-school-admissions` `8170adf`). Raised from `docs/BuzzMe_Attendance_SRS_Gap_Analysis.md`'s recommendation #3.
**Backlog item:** `BK-ATT-2` (Epic 4, Attendance Officer) — *"Government-mandated attendance codes only; reject others"* — currently `BLK`, tracked against **Open Issue O4** ("Government census + attendance code/exam format specs — Regulatory attach").
**Author:** +ER Education session, 2026-09-22.

**Direct instruction, 2026-09-22, supersedes this proposal's original recommendation #2/#3 caution**: *"We can go with the flow of the UK system as at now. If and when there is a Nigerian code, we will separate the education jurisdictions."* The nine UK DfE-style codes below are now adopted as real seed data (`AttendanceCode` enum, `domain/attendance/AttendanceModels.kt`), not merely a labeled-placeholder table — mirroring this project's own tax-jurisdiction precedent (a single global table today, UK/IE/NG/SL/LR/GN/CI split later once a real source exists per jurisdiction, not before). **O4 stays open** in the sense that no Nigerian source has been found or attached — but the platform no longer blocks on that; it runs on the UK table now, with jurisdiction-splitting deferred until a Nigerian source surfaces, not until BK-ATT-2 itself is "closed."

## Current state

`AttendanceCode` (`domain/attendance/AttendanceModels.kt`) is a closed 3-value enum:

```kotlin
enum class AttendanceCode { PRESENT, ABSENT, LATE }
```

`parseOrThrow()`'s own rejection message says it plainly: *"MVP allows PRESENT/ABSENT/LATE only; gov codes BLK"*. This has been blocked since W3 because nobody had a real government-mandated code list to attach — not a technical limitation, a missing input.

## What FR-36 (SRS-ATT-001 §4.4) proposes

> The school shall configure codes (e.g. `/` present, `L` late, `N` unexplained, `I` illness, `M` medical, `C` other authorised, `V` educational visit, `B` off-site, `E` excluded). Each code has: display, statutory category, counts-in-% flag.

Two genuinely different things are bundled in that one requirement, and they deserve different treatment:

### 1. The shape — recommend adopting now

Each mark code carries three properties today's bare enum has none of:
- **`display`** — the short symbol shown on a register (`/`, `L`, `N`, ...)
- **`statutory category`** — a broader grouping a code rolls up into for reporting (e.g. "present," "authorised absence," "unauthorised absence")
- **`counts-in-%`** — whether this code counts toward the published attendance percentage, or is excluded from the calculation entirely (some jurisdictions exclude authorised educational-visit time from the denominator, for example)

This is jurisdiction-independent, well-designed, and directly useful regardless of which country's actual codes end up populating it. It's also exactly the shape `FR-35` already gestures at ("codes compatible with the school's national attendance coding scheme (**configurable table**)") — the SRS's own language already expects this to be data, not a hardcoded enum.

### 2. The specific codes — do not adopt as "official" yet

The nine example codes (`/ L N I M C V B E`) are recognisably the **UK's own DfE school-attendance code set** — the SRS is UK-authored throughout (its named MIS peers are SIMS/Arbor/Bromcom, all UK products). I checked this project's own docs before writing this proposal: **nothing here has researched Nigeria's actual Ministry of Education / UBEC attendance-coding scheme.** FiSH's real target market for The Principal is Nigeria, not the UK.

O4 exists specifically because attaching a code list is a *regulatory* act, not a technical one — the same discipline this project already applies everywhere else a real government figure is needed (every jurisdiction's tax/currency settings doc cites a real, dated primary source before a number gets used). Treating FR-36's UK table as "the official list" to close BK-ATT-2 would quietly break that discipline: it would resolve a Nigeria-market regulatory question using a UK source, without anyone having checked whether Nigerian schools even report attendance the same way.

## Recommendation (original) / What was actually built

1. **Build the shape now**: replace the closed `AttendanceCode` enum with a configurable code table (`code`, `display`, `statutoryCategory`, `countsInPercent`). **Done** — the 9-value enum (`PRESENT/LATE/UNEXPLAINED/ILLNESS/MEDICAL/AUTHORISED_OTHER/EDUCATIONAL_VISIT/OFF_SITE/EXCLUDED`) now carries all three properties.
2. **Seed it with FR-36's UK table as an explicit placeholder** — superseded by the direct instruction above: it's adopted as real data, not a labeled placeholder, though the code's own KDoc still notes `statutoryCategory`/`countsInPercent` are a reasonable development interpretation, not independently verified against a primary DfE source (the same "treat as unverified until sourced" caveat this project applies to every other borrowed regulatory figure).
3. **Keep BK-ATT-2/O4 open** until a real Nigerian source is found — still true; the UK table runs in the meantime rather than blocking on it.
4. **Migrate existing data deliberately**: `V17__attendance_mark_code_table.sql` backfills any already-persisted `ABSENT` rows to `UNEXPLAINED` (the direct successor with the same `UNAUTHORISED_ABSENCE` statutory shape), not a silent reinterpretation.

Sequencing/build is complete for this piece. The next open item under the same jurisdiction-splitting plan is finding a real Nigerian attendance-code source — not scheduled, same "park, don't guess" treatment as this project's other unsourced regulatory gaps.
