# The Principal — MVP Definition

**Date:** 2026-09-19
**Grounded against:** `The_Principal_SRS.md` (17 Sep 2026), `The_Principal_Backlog.md` (tip `f42f459`, W0–W5 landed, W6 unparked), the Business Development & Roll-Out Plan's Phase 1 (Pilot & validation, Months 1–6, ~100 schools · ~40,000 students), and the second code review (2026-09-19, 8 findings, fixed on `claude-code-review` @ `b272deb`, not yet merged to `master`).

## The test this document applies

Not "everything the SRS calls Must" — the SRS marks 32 functional requirements Must, which is the *full product vision*, not a launch gate. The test here is narrower: **what does the Pilot phase (Path-to-1M §06) actually need to be true** for ~100 hand-picked schools to run real students' real data through this system safely, with the Pilot's own stated validation goals (onboarding time, **TPI/SPI credibility with real teachers**, offline sync under real connectivity) met. Government census/compliance reporting is explicitly a later-phase concern (Regional Scale, §06) except for the one government pilot cohort named in Phase 1 — flagged below as a real open question, not resolved here.

## In scope for MVP (ship before any pilot school gets real data)

| Area | Backlog ref | Status |
|---|---|---|
| Multi-tenant school isolation | BK-PLT-1 | **Done**, verified twice (0fcab3b tenant-isolation fix; this review's shared `TenantIdGuard.lookupAndRequireSameTenant` hardening) |
| ER identity/RBAC consumption | BK-PLT-2 | **Done** (`ErPrincipal`/`ErIdentityGateway`, stub pending real ER SRS) |
| FiSH SOP outbound event bus, idempotent | BK-PLT-3 | **Done as of this review** — the 2026-09-19 fixes (deterministic `eventId` on all four event types, outbox-first ordering, JSON escaping) are what make this bus's own idempotency claim actually true. **Not yet merged to `master` or deployed.** |
| No direct FiSH GL writes | BK-PLT-4 | **Done** (`NoDirectGlWrites` gate; SOP-event-only path) |
| Student Register (bio, guardians, class, safeguarding flags) | BK-REG-1 | **Done** |
| Safeguarding fields restricted to authorised roles | BK-REG-3 | **Done** (`canAccessSafeguarding()`) |
| Bulk CSV import for onboarding | BK-REG-4 | **Done** |
| Classes/sections/timetables + conflict detection | BK-CLS-1/2 | **Done** |
| Admissions pipeline → `StudentEnrolled` | BK-ADM-1/3/4 | **Done** |
| Attendance marking + codes → `AttendanceRecorded` | BK-ATT-1/4 | **Done**, with a caveat (see Deferred) |
| Grade entry + publish → `AssessmentCompleted` | BK-ASS-1/3/4 | **Done** |
| Fee schedule + invoicing + manual payment confirmation → `StudentPaymentReceived` | BK-FEE-1/3/4 | **Done** — see the O3 reframe below, this does not need a live payment gateway for Pilot |
| Guardians view attendance/grades/fee status | BK-PAR-1 | **Not built** (W6 just unparked) — the read-only view, not notifications |

## The two real MVP gates (decisions, not code)

**O1 — SPI/TPI formulae.** This is the one Must-tagged item that's both (a) genuinely blocked on a non-engineering decision and (b) explicitly named in the Path-to-1M plan as something Phase 1 exists to validate ("TPI/SPI credibility with real teachers"). It can't be deferred out of MVP the way the other BLK items below can — **product/education leadership signing off the formulae is the actual critical-path item for Pilot,** not more code. `BK-ASS-5/6/7` are ready to compute and gate access the moment O1 resolves.

**Merging and deploying this review's fixes.** The outbox-idempotency, error-mapping, and tenant-guard fixes from 2026-09-19 exist only on `claude-code-review` (`b272deb`) right now. No pilot school's data should touch this system until that branch is cherry-picked to `master`, deployed, and — since there is currently **no Postgres-backed integration test anywhere in this codebase** (only in-memory unit tests, 66/66 passing) — re-verified against a real database. Compile-only confidence on the Exposed-store changes is not the same as verified confidence.

## Reframed, not blocking: O3 (payment provider)

The backlog flags `BK-FEE-2/3` as **BLK** on payment-provider selection, but `FeeService.confirmPaymentStub()` already does exactly what a hand-picked private-school pilot needs: a bursar records a cash/bank-transfer payment manually, the system emits `StudentPaymentReceived` correctly. A live gateway (Paystack primary, per the backlog's 2026-09-18 entry) is a **Focused Expansion** concern (self-serve guardian payment at volume across 1,000+ schools), not a Pilot one. **O3 does not block MVP** — worth correcting in the backlog, which currently reads as if it does.

## Explicitly deferred past MVP

- **O4 (government census/exam-format specs), Compliance Centre (Epic 8/W7).** Not built at all yet. Genuinely fine to defer *unless* the one named government pilot cohort (Path-to-1M §06) requires a real census export inside the 6-month pilot window — **flagged as open, not resolved**, since nobody has checked what that specific cohort actually needs yet.
- **O2 (SMS vs push) and `BK-PAR-3` (notifications).** The read-only Parent Gateway view (`BK-PAR-1`) covers the Pilot's actual need; push/SMS delivery is a retention/engagement feature for scale, not a Pilot gate.
- **`BK-ATT-2`/`BK-ASS-2` (government-mandated code/format lock).** The current code enforces a placeholder MVP code set (`AttendanceCode`), not the real government list (O4). Fine for a private-school pilot; becomes a real gap the moment the government pilot cohort or any state contract is in play.
- **Epic 5b (Curriculum & Learning Roadmap).** Explicitly sequenced *before* SPI/TPI can compute for real, but the roadmap/curriculum-mapping UI itself isn't a Pilot-user-facing requirement — only the SPI/TPI numbers it eventually feeds are.
- **`BK-PLT-7` Flutter mobile.** SRS already marks this Should, not Must, for first release; web is primary.
- **`BK-NFR-3`/`BK-NFR-7` (500 concurrent sessions/school, 5k-school scale path).** Real, but Pilot's own ~40,000-student, ~100-school scale doesn't exercise this ceiling — validate against actual Pilot load, not the Year-3 target, per the backlog's own O5.

## What this changes about the backlog

Two corrections worth making in `The_Principal_Backlog.md` directly, since the current wording overstates what's actually blocking: (1) O3 should not be listed as blocking `BK-FEE-2/3` for MVP — only for the volume-payment feature; (2) the government pilot cohort's census/compliance needs are currently unresearched, not merely deferred — worth a direct question rather than an assumed answer.
