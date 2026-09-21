# The Principal — Product Backlog

**Source:** The Principal SRS (17 Sep 2026)  
**Owner:** Policy and Strategy Initiatives CIC  
**Platform:** FiSH+ER (school EMIS, Nigeria)  
**Project folder:** `C:\Users\femif\Claude\Projects\FiSH\ER\Principal`  

**Status:** **W0–W6 landed and live in production** (tip `7b06f70`, 2026-09-20), plus BK-ATT-6 (UC-20 automated attendance capture). Full CI/CD stood up 2026-09-20: GitHub repo, FiSH submodule, Terraform infra, Jenkins pipeline — deployed to `https://school-api.theprodeogroup.com`. **Both items this doc used to flag as blocking production-safety are now closed**: real Cognito JWT auth (human `StaffAssignment`-based + a service-account path for DPID) replaced `StubErIdentityGateway` the same day, and every Exposed store (Admissions/Attendance/Assessment/Fee/School/StaffAssignment) now has real-Postgres integration test coverage, not just in-memory unit tests. W6 thin Parent Gateway sealed. Live payment rails BLK (O3). Epic 5b Curriculum parked until O1 — capacity now exists (W0–W6 done) but formulae (O1) still isn't. RoI VAT remains separate FiSH WIP. **Still not fully production-safe for real school data**: no SchoolAdmissions frontend exists yet (BK-PLT-2's "shared nav chrome" half, staff-management routes are API-only) — **handed off to the dedicated `FiSH+ER WEB` thread 2026-09-21**, tracked there going forward, not built inline in this backend-focused thread — and BK-ATT-6's own DPID caller side isn't built yet (BuzzMe's Open Question 1 resolved 2026-09-20, but the real `PrincipalAttendanceGateway` HTTP implementation and the actual mobile/BLE client are both still ahead; BK-REG-5, the identity-linkage lookup that implementation will call, is FiSH+ER's own next backend item).
**Maintained by:** Code Reviewer (review/SRS); implementation by Code Writer when unparked.

## Priority legend

| Tag | Meaning |
|-----|---------|
| **M** | Must have (MoSCoW) |
| **S** | Should have |
| **C** | Could have |
| **NFR** | Non-functional |
| **BLK** | Blocked on open TBD / external decision |
| **DEP** | Depends on another backlog item or platform service |

## Recommended delivery waves (dependency order)

When unparked, build in this order — not by module vanity:

| Wave | Focus | Why first |
|------|--------|-----------|
| **W0** | Platform contracts | ER auth/RBAC assumptions; FiSH SOP event envelope (idempotent ID + timestamp); multi-tenant school isolation |
| **W1** | Student Register + Classroom Manager (core M) | Canonical student + class model everything else hangs on |
| **W2** | Admissions Office (M) → `StudentEnrolled` | Feeds register; first SOP event |
| **W3** | Attendance Officer (M) + offline sync → `AttendanceRecorded` | High-frequency classroom path; NFR offline |
| **W4** | Assessment Hub grades + report cards (M) | Needs register/class; SPI/TPI **BLK** until formulae signed off |
| **W5** | Fee Desk (M) + payment provider → `StudentPaymentReceived` | Needs student; **BLK** on payment provider; never direct GL |
| **W6** | Parent Gateway (M) | Needs attendance, grades/SPI, fee status |
| **W7** | Compliance Centre (M) | Needs audit trail + attendance patterns + census export formats (**BLK**) |
| **W8** | Should/Could + polish | Offer letters, bulk CSV, alerts, notifications channel (**BLK**) |
| **Before SPI/TPI** | Curriculum & Learning Roadmap (Epic 5b) | **Must precede** ASS-5/6; structure/progress inputs for indices; not LMS content |

---

## Epic 0 — Platform & architecture (cross-cutting)

| ID | Item | Pri | Notes |
|----|------|-----|-------|
| BK-PLT-1 | Multi-tenant isolation per school (NFR-CMP-3) | M | Align with FiSH GLaaS tenancy patterns; school = tenant boundary for The Principal |
| BK-PLT-2 | Consume ER identity + RBAC + shared nav chrome | M | Identity+RBAC half **done 2026-09-20** (real Cognito JWT, `StaffAssignment` per-school roles) — see change log. "Shared nav chrome" half still open: no SchoolAdmissions frontend exists in WEB yet, so the 3 new staff routes are API-only today. |
| BK-PLT-3 | FiSH SOP outbound event bus (idempotent, event ID, timestamp) | M | All §4.2 events |
| BK-PLT-4 | Hard rule: no direct FiSH GL writes (FR-FEE-4 / §2.5) | M | Review gate on every Fee Desk / payment PR |
| BK-PLT-5 | Design system: Authority Blue / Academic Gold, Merriweather/Inter, WCAG 2.1 AA | M | Brand + UI/UX refs |
| BK-PLT-6 | Offline-first local store + sync + conflict resolution (most recent authoritative) | M | NFR §6.2; used by ATT/ASS/lookup |
| BK-PLT-7 | React+TS web (primary staff); Flutter mobile optional first release | S | §5.1 |

---

## Epic 1 — Student Register

| ID | SRS | Item | Pri | Deps / blockers |
|----|-----|------|-----|-----------------|
| BK-REG-1 | FR-REG-1 | Canonical student profile (bio, guardians, class, medical/safeguarding flags) | M | W1 |
| BK-REG-2 | FR-REG-2 | Versioned profile changes + audit trail | M | BK-REG-1 |
| BK-REG-3 | FR-REG-4 | Restrict safeguarding fields to authorised roles (API + UI) | M | BK-PLT-2, NFR-SEC-* |
| BK-REG-4 | FR-REG-3 | Bulk CSV import/export (onboarding + census) | M | **W1 unparked (bulk init)**; BK-REG-1; census format **BLK** (see Open) |
| BK-REG-5 | — (BuzzMe UC-20 follow-on) | DPID identity linkage: `dpidIdentityId` field on `StudentProfile` + reverse-lookup route so DPID's `PrincipalStudentDirectory.resolveStudentId()` can resolve a real student | M | **Done 2026-09-21** (`7472cb3`). `GET /schools/{schoolId}/students/by-dpid-identity/{identityProfileId}` returns only `{"studentId": "..."}`, not a full profile — deliberate narrowing from BuzzMe's own proposal, since the caller only ever needs the id. Gated by a new `canLookupByDpidIdentity()` (SCHOOL_ADMIN/REGISTRAR/the existing `DEVICE_ATTENDANCE_CAPTURE` service-account role), not open to every authenticated principal. `V9` migration adds a partial unique index; found and fixed a real gap along the way — `ExposedSchoolStore.putStudent()` was the only Exposed store with no unique-violation-to-`IllegalStateException` handling. Note: populating the field (at credential-issuance time) is still BuzzMe's own separate, unbuilt step — this closed the read-side lookup only. Confirmed accepted by BuzzMe, no concerns with the contract. **Operational heads-up from BuzzMe**: until their credential-issuance flow exists, every `by-dpid-identity` lookup 404s by design, not by bug — worth knowing before anyone tests this endpoint expecting real data. |
| BK-REG-6 | — (BuzzMe UC-20 follow-on, write side) | DPID identity linkage: write endpoint so BuzzMe's `IssueCredentialUseCase`/`PrincipalStudentDirectory.linkIdentity()` can actually populate `StudentProfile.dpidIdentityId` on a real student — BK-REG-5 only ever built the read side | M | **Done 2026-09-21** (`75dfaf2`). `POST /schools/{schoolId}/students/{studentId}/dpid-identity` — plain-text `identityProfileId` body, matching this repo's other single-value routes; `200 {"studentId", "dpidIdentityId"}` on success, `409` via the same `putStudent()` unique-constraint conflict BK-REG-5 already established, `404` if the student doesn't exist. New `SchoolStore.linkDpidIdentity()` delegates to `putStudent()` for tenant/register-rights checks rather than duplicating them, and deliberately skips `getStudent()` so linking an identity doesn't spuriously log a `PastoralAccessLogEntry`. Resolves BuzzMe's own open question ("who initiates this?"): gated on `canManageRegister()` — a human SCHOOL_ADMIN/REGISTRAR, not the `DEVICE_ATTENDANCE_CAPTURE` service account — since register writes stay human-gated platform-wide (`AdmissionsService.enrol()`'s own "never mint register rights in-process" precedent). |

---

## Epic 2 — Classroom Manager

| ID | SRS | Item | Pri | Deps / blockers |
|----|-----|------|-----|-----------------|
| BK-CLS-1 | FR-CLS-1 | Classes, sections, timetables CRUD | M | W1 |
| BK-CLS-2 | FR-CLS-2 | Assign teachers to classes/subjects; detect timetable conflicts | M | BK-CLS-1 |
| BK-CLS-3 | FR-CLS-3 | Mid-year class transfers with history | S | **Done 2026-09-21** (`3ff7204`). New `SchoolStore.transferStudentClass()`/`classTransferHistoryFor()`, a dedicated `ClassTransferEntry` + `class_transfers` table (`V11`) — delegates to `putStudent()` for the actual write (so the generic `StudentAuditEntry` trail still fires) but adds a structured from/to record, since the generic audit snapshot never actually named which class section changed. `POST /schools/{schoolId}/students/{studentId}/transfer-class` + `GET .../class-transfers`, both gated `canManageRegister`. Found and fixed a real ordering bug while testing: the in-memory store's transfer log was a hash-based `Set`, whose iteration order isn't insertion order — two transfers landing on the same `Instant.now()` sorted nondeterministically; switched to an insertion-order list, and pre-emptively added an autoincrement `seq` column on the Postgres side for the same reason. |

---

## Epic 3 — Admissions Office

| ID | SRS | Item | Pri | Deps / blockers |
|----|-----|------|-----|-----------------|
| BK-ADM-1 | FR-ADM-1 | Application pipeline: Submitted → Under Review → Offered → Accepted → Enrolled | M | W2 |
| BK-ADM-2 | FR-ADM-2 | Document upload + admissions checklist review | M | BK-ADM-1 |
| BK-ADM-3 | FR-ADM-5 | Prevent duplicate enrolment same student / academic year | M | BK-ADM-1, BK-REG-1 |
| BK-ADM-4 | FR-ADM-4 | Emit `StudentEnrolled` to FiSH SOP on enrolment | M | BK-PLT-3, BK-ADM-1 |
| BK-ADM-5 | FR-ADM-3 | Offer letters + guardian accept/decline | S | **Done 2026-09-21** (`f7440df`). `AdmissionStatus` gains `DECLINED` — a real terminal alternative to `ACCEPTED` from `OFFERED` (previously the pipeline could only move forward). `AdmissionApplication` gains `offerLetterRef` (stamped on `OFFERED`, thin like `documentChecklistJson` — a generated reference, not real document generation) and `guardianDecisionMethod`/`guardianDecisionAt` (stamped on `ACCEPTED`/`DECLINED`). Deliberately staff-recorded, not guardian self-service: a not-yet-enrolled applicant's guardian has no `Guardian.subjectId` link yet to authenticate through Parent Gateway (Epic 7 is post-enrolment only) — office staff record what the guardian communicated, same shape as every other admissions transition. `POST .../admissions/{id}/transition`'s body gains an optional pipe-delimited method field; a bare status string (every existing caller) still works unchanged. |

**Event payload (BK-ADM-4):** student ID, school ID, class ID, enrolment date + event ID + timestamp.

---

## Epic 4 — Attendance Officer

| ID | SRS | Item | Pri | Deps / blockers |
|----|-----|------|-----|-----------------|
| BK-ATT-1 | FR-ATT-1 | Mark present/absent/late per student per class session | M | BK-CLS-*, BK-REG-1 |
| BK-ATT-2 | FR-ATT-3 | Government-mandated attendance codes only; reject others | M | **BLK:** attach official code list. BuzzMe flagged 2026-09-21: their own newer attendance SRS names a concrete mark-code table (present/late/unexplained/illness/etc.) that would replace the current `PRESENT`/`ABSENT`/`LATE` enum — a real candidate for the "official code list" this item is waiting on, not yet attached/adopted here. |
| BK-ATT-3 | FR-ATT-2 | Offline capture + auto-sync on reconnect | M | BK-PLT-6; NFR-PRF-2 (≤60s sync) |
| BK-ATT-4 | FR-ATT-4 | Emit `AttendanceRecorded` to FiSH SOP | M | BK-PLT-3 |
| BK-ATT-5 | FR-ATT-5 | Attendance-pattern alerts → Compliance Centre | S | BK-ATT-1, Epic 8 |
| BK-ATT-6 | FR-36 (lesson-level) | Automated/device-originated capture (UC-20: RFID card + Bluetooth reader on teacher's device) | M | SchoolAdmissions-side **done** 2026-09-20 (`LessonSlotResolver`, `AttendanceService.mark()` overload, `POST /schools/{schoolId}/attendance/auto`, reviewed+hardened same day). **Service-account auth also done same day**: `CognitoErIdentityGateway` gained a second, optional service-account JWT verifier (`buildJwksServiceVerifierForDpid`, `DEVICE_ATTENDANCE_CAPTURE` role, bypasses the StaffAssignment lookup entirely); a real Cognito app client for DPID provisioned in FiSH's shared pool (`Infrastructure/dpid_schooladmissions_service_account.tf`, client id `1pci0m6m2o8cq55e7tu20jssqs`) — a deliberate, explicit exception to "shared pool = FiSH-internal only," decided knowing the trade-off, not a default. Live in production (task def `:8`). **Still BLK, on DPID's own side only**: no real HTTP implementation of `PrincipalAttendanceGateway` yet (needs DPID's Open Question 1 — identity mapping — resolved first), and the actual mobile/BLE reader client is separate future work outside either backend's scope. |

**Event payload (BK-ATT-4):** student ID, class ID, date, attendance code + event ID + timestamp. BK-ATT-6 additionally carries `operatorId`/`occurredAt`/optional `zoneId`, and its SOP eventId is lesson-scoped (not just date-scoped) to avoid colliding two lessons the same day.

---

## Epic 5 — Assessment Hub

| ID | SRS | Item | Pri | Deps / blockers |
|----|-----|------|-----|-----------------|
| BK-ASS-1 | FR-ASS-1 | Grade entry per student per subject vs assessment structure | M | BK-REG-1, BK-CLS-* |
| BK-ASS-2 | FR-ASS-6 | Lock exam result formats to government-mandated structures | M | **BLK:** attach format spec |
| BK-ASS-3 | FR-ASS-4 | Publish report cards to Parent Gateway on release approval | M | BK-ASS-1, Epic 7 |
| BK-ASS-4 | FR-ASS-5 | Emit `AssessmentCompleted` to FiSH SOP on publication | M | BK-PLT-3 |
| BK-ASS-5 | FR-ASS-2 | Compute/display SPI per student per term | M | **After** Epic 5b (BK-CUR-3); **BLK:** formulae (Open #1) |
| BK-ASS-6 | FR-ASS-3 | Compute/display TPI per teacher per term | M | **After** Epic 5b (BK-CUR-3); **BLK:** formulae (Open #1) |
| BK-ASS-7 | §4.1 | Store historical SPI/TPI per term; access rules (SPI: guardians own child + staff; TPI: admin + self, not peers/guardians) | M | BK-ASS-5/6 |

**Event payload (BK-ASS-4):** student ID, term, SPI value, grade summary + event ID + timestamp.

---


## Epic 5b — Curriculum & Learning Roadmap (**before SPI/TPI** — parked until unparked)

Subject-by-subject curriculum / learning roadmap for each class/year. **Not** LMS course-content delivery (still out of scope). Feeds SPI/TPI once formulae (O1) are signed off.

| ID | Item | Pri | Deps / blockers |
|----|------|-----|-----------------|
| BK-CUR-1 | Subject curriculum map per school/year (topics, sequence, term coverage) | S | **Done 2026-09-21** (`10b31c7`), unparked and worked on direct instruction alongside the rest of the explicit dependency-ordered backlog pass, ahead of O1's formulae. New `CurriculumTopic` aggregate + `curriculum_topics` table (unique on school/subject/year/sequence) — structure only, never content. `CurriculumService.defineTopic()`/`curriculumMapFor()` mirrors `AssessmentService`'s find-by-natural-key-then-upsert shape. Reuses `canEnterGrades()`'s academic-staff role set rather than adding a new permission — a judgment call, not a settled answer to BK-CUR-4's own "academic-track RBAC" question, which stays open for later. |
| BK-CUR-2 | Learning roadmap / scheme-of-work progress vs curriculum map | S | BK-CUR-1 |
| BK-CUR-3 | Feed curriculum coverage + progress into SPI/TPI inputs | M | BK-CUR-1/2 first; then unlocks BK-ASS-5/6 with O1 formulae |
| BK-CUR-4 | Teacher view: roadmap adherence for own subjects/classes | S | BK-CUR-2; academic-track RBAC |

**Note:** LMS / rich course content remains explicitly out. This epic is structure + progress signals for accountability indices, not a content platform.

---
## Epic 6 — Fee Desk

| ID | SRS | Item | Pri | Deps / blockers |
|----|-----|------|-----|-----------------|
| BK-FEE-1 | FR-FEE-1 | Invoices per student per billing cycle from fee schedule | M | BK-REG-1 |
| BK-FEE-2 | FR-FEE-2 | Guardians pay via Parent Gateway | M | BK-FEE-1, Epic 7; **BLK:** payment provider |
| BK-FEE-3 | FR-FEE-3 | On payment confirmation emit `StudentPaymentReceived` to FiSH SOP | M | BK-PLT-3, BK-FEE-2 |
| BK-FEE-4 | FR-FEE-4 | Never write GL entries directly | M | Review gate |
| BK-FEE-5 | FR-FEE-5 | Real-time fee-outstanding on dashboard | S | BK-FEE-1/3 |

**Event payload (BK-FEE-3):** student ID, invoice ID, amount, payment date, method + event ID + timestamp.

---

## Epic 7 — Parent Gateway

| ID | SRS | Item | Pri | Deps / blockers |
|----|-----|------|-----|-----------------|
| BK-PAR-1 | FR-PAR-1 | Guardians view child attendance, grades/SPI, fee status | M | Epics 4–6 |
| BK-PAR-2 | FR-PAR-3 | Usable on low-end mobile + intermittent connectivity | M | BK-PLT-6 |
| BK-PAR-3 | FR-PAR-2 | Notifications: attendance anomalies, reports, invoices | S | **BLK:** SMS vs push (Open #2) |

---

## Epic 8 — Compliance Centre

| ID | SRS | Item | Pri | Deps / blockers |
|----|-----|------|-----|-----------------|
| BK-CMP-1 | FR-CMP-1 | Immutable audit log for pastoral/safeguarding notes | M | **Done 2026-09-21** (`20215d7`). New `PastoralAccessLogEntry` (NFR-SEC-2's own "all access... captured" wording, distinct from `StudentAuditEntry`'s change-tracking) written automatically inside `getStudent()` whenever a safeguarding-visible principal reads a genuine pastoral note. Also closed a real pre-existing gap this surfaced: `StudentAuditEntry` (BK-REG-2) had been built and written to since W1 but never had a route to read it back — `GET /schools/{schoolId}/students/{id}/audit` now returns both, gated by `canAccessSafeguarding`. |
| BK-CMP-2 | FR-CMP-4 | RBAC on sensitive fields across all modules (API-enforced) | M | **Done 2026-09-21** (`34f591c`). Grep-driven audit of every `safeguardingFlags`/`medicalNotes` touch-point. Real gap found and closed: `listStudents()` had no `ErPrincipal` parameter and applied no masking at all, unlike `getStudent()` — unused by any route today (not a live leak) but a landmine for the next roster-view route. False alarm ruled out after reading the actual consumer: `studentsByExternalRef()`'s two callers (CSV import, admissions enrol) are both already gated correctly and never serialize its raw values to a response — left as-is, just documented as internal-only. |
| BK-CMP-3 | FR-CMP-2 | Critical alerts: attendance, safeguarding, census-validation | M | BK-ATT-5, BK-CMP-1 |
| BK-CMP-4 | FR-CMP-3 | Government census exports in mandated format | M | **BLK:** format spec (Open #4) |

---

## Epic 9 — Non-functionals (track with waves)

| ID | SRS | Item | Pri | Wave |
|----|-----|------|-----|------|
| BK-NFR-1 | NFR-PRF-1 | Dashboard/tables ≤3s on 3G-equivalent | NFR | W1+ |
| BK-NFR-2 | NFR-PRF-2 | Offline sync ≤60s after reconnect | NFR | W3 |
| BK-NFR-3 | NFR-PRF-3 | ≥500 concurrent sessions/school at peak | NFR | Capacity; validate vs Year 1 pilot (Open #5) |
| BK-NFR-4 | NFR-SEC-1 | Pastoral fields masked by default | NFR | W1/W8 |
| BK-NFR-5 | NFR-SEC-4 | Encryption at rest and in transit | NFR | W0 |
| BK-NFR-6 | §6.4 | WCAG 2.1 AA + high-contrast mode | NFR | Ongoing |
| BK-NFR-7 | NFR-CMP-2 | Scale path to 5k schools / 1M students (AWS) | NFR | Architecture; not Year-1 gate |

---

## Open issues (block listed Musts)

| # | Open item | Blocks | Owner |
|---|-----------|--------|-------|
| O1 | TPI/SPI exact formulae & weightings (curriculum coverage is an intended input — Epic 5b before ASS-5/6) | BK-ASS-5, BK-ASS-6, BK-ASS-7 | Product/education leadership |
| O2 | Parent notification channel (SMS / push / both) | BK-PAR-3 | Market research |
| O3 | Payment provider(s) for Fee Desk | BK-FEE-2, BK-FEE-3 | Product / ops |
| O4 | Government census (+ attendance code / exam format) specs | BK-ATT-2, BK-ASS-2, BK-CMP-4, BK-REG-4 | Regulatory attach |
| O5 | Validate NFR-PRF-3 / NFR-CMP-2 sizing vs Year 1 pilot | Capacity planning | Eng + product |

---

## Explicitly out of backlog (per SRS)

- FiSH GL posting rules / CoA (FiSH SRS)
- ER identity/admin implementation (ER SRS)
- LMS / rich course content delivery (curriculum *structure* + learning roadmap is Epic 5b, later — not content hosting)
- RoI VAT MVP work (separate FiSH track — current WIP priority)

---

## Counts

| Priority | FR count (approx) |
|----------|-------------------|
| Must (M) | 32 functional + core NFRs |
| Should (S) | 6 |
| Could (C) | 0 in SRS |
| Blocked Musts pending O1–O4 | SPI/TPI, attendance codes, exam formats, census, payments, notifications |

## Change log

| Date | Change |
|------|--------|
| 2026-09-17 | Initial backlog from The Principal SRS; parked pending RoI VAT MVP |

| 2026-09-17 | Femi: domain name SchoolSOP → SchoolAdmissions; BK-REG-4 bulk CSV initialise promoted into W1 Must |
| 2026-09-18 | W0–W2 landed (tip `723ccbb`); W3 Attendance unparked for Code Writer |
| 2026-09-18 | W3 Attendance sealed (9a7fe2d); W4 Assessment unparked (SPI/TPI still BLK) |
| 2026-09-18 | Parked Epic 5b Curriculum & Learning Roadmap (later); feeds SPI/TPI; LMS content stays out |
| 2026-09-18 | W4.5 Persistence hardening unparked (Exposed ADM/ATT/ASS + durable outbox) before W5 |
| 2026-09-18 | Femi: Curriculum (Epic 5b) before SPI/TPI — reorder dependency (not after indices) |
| 2026-09-18 | W5 Fee Desk (thin) unparked; 5b Curriculum stays parked until O1; fee/parent vs indices = parallel tracks |
| 2026-09-18 | W5 sealed `f42f459`; Nigeria payment = W6 Parent thin first; O3 shortlist Paystack primary / Flutterwave alt (docs-only until credentials) |

| 2026-09-19 | W5.1 sealed `0b7cf44` (deterministic eventIds + outbox-first enrol/attendance); W6 still parked |
| 2026-09-19 | W6 thin Parent Gateway sealed `ca92b01` |
| 2026-09-19 | Second review (W2-W5, 8 findings) closed `501cf05`: outbox idempotency completed across all four event types, shared `TenantIdGuard`/`requireSchoolAccess` helpers, in-memory stores now upsert-by-id to match Exposed |
| 2026-09-20 | CI/CD stood up `de0c9b5`: GitHub repo (`prodeo-group-dev/fish-school-admissions`, private), wired as FiSH's 11th submodule, Dockerfile/Jenkinsfile, full Terraform stack, shared-RDS DB provisioned, Jenkins Multibranch job |
| 2026-09-20 | First production deploy verified end-to-end: live at `school-api.theprodeogroup.com`, real Postgres confirmed via Flyway/HikariCP logs (not just `/health` liveness) |
| 2026-09-20 | BK-PLT-2 (identity+RBAC half) closed `88d2e73`: `StubErIdentityGateway` replaced by real Cognito JWT verification in production (`SCHOOLADMISSIONS_AUTH_MODE=cognito` default); new `StaffAssignment` per-school role store (`TEACHER`/`REGISTRAR`/`SCHOOL_ADMIN`/etc. — EA's own `Role` enum has nothing matching these) + 3 routes to manage it; `GUARDIAN` stays computed from existing `Guardian.subjectId` links. First SCHOOL_ADMIN per school is still a manual DB seed (decided, not automated) — self-service staff invites work from there. Production task definition patched (`:3`) and new code deployed (`:4` pending) same day. New known gap surfaced, not yet backlog-numbered: no WEB UI for the 3 new staff routes — API-only until BK-PLT-2's "shared nav chrome" half is picked up. |
| 2026-09-20 | BK-ATT-6 (UC-20, new item) added and its SchoolAdmissions-side built same day by a concurrent BuzzMe-thread session (`fish-school-admissions` PR #1, `4a68daf`/`f573bfe`) — explicit ownership split confirmed after the fact: BuzzMe owns DPID/capture, FiSH+ER owns lesson resolution/recording. Reviewed same day (8 findings, 6 fixed `6a16694`): most severe was a day-granular natural key silently overwriting two different lessons' marks on the same day — now lesson-scoped in the in-memory key, a new Postgres unique index (`V8`), and the SOP eventId. Also fixed: guarded `Instant`/`ZoneId` parsing (was crashing 500 on malformed input), a real optional `zoneId` field (lesson resolution was silently always UTC), blank-`operatorId` validation, and a narrower `lessonsForSection` query. `COORDINATION.md` added to both `fish-school-admissions` and `BuzzMe` the same day to prevent this near-duplicate-build pattern recurring. |
| 2026-09-20 | BK-ATT-6's remaining service-account auth gap closed same day (`c187bba` app code, `7622feb` infra): `CognitoErIdentityGateway` gained a second, optional service-account JWT verifier + `DEVICE_ATTENDANCE_CAPTURE` role (bypasses `StaffAssignment` lookup, same module-to-module precedent used elsewhere on the platform); real Cognito app client provisioned for DPID in FiSH's own pool — an explicit, deliberate exception to the pool's usual FiSH-internal-only scope, decided knowing DPID isn't a FiSH venture. Also: this session's own AWS access moved off the account root user onto a scoped IAM identity (`fish-gl-engine-terraform`) mid-build, closing an unrelated standing risk. |
| 2026-09-20 | Same-day DPID Cognito client rotated: a peer session's existence check (`describe-user-pool-client`) pulled the client secret into its own context in plaintext (not externally exposed, but avoidable). Rotated via `terraform apply -replace` (Cognito has no in-place secret regen, so the client id changed too — `1pci0m6m2o8cq55e7tu20jssqs` → `a9fmkdsajbj2uhasc0a8qlfvc`); production task definition repatched, confirmed healthy. Lesson recorded: use `list-user-pool-clients` for any future existence check on a credentialed client, never `describe-user-pool-client`. |
| 2026-09-20 | Remaining Postgres integration test coverage closed (`7b06f70`): `Admissions`/`Assessment`/`Fee`/`School` Exposed stores each got real-DB tests (34 total across all 6 stores now), verifying actual unique-index behavior, tenant-guard rejection, and `ExposedSchoolStore`'s guardian pipe/semicolon/backslash-escaping round trip. Two of the new tests' own test-data bugs (a shared hardcoded natural key, a non-unique teacherId colliding with a prior run via the real `TimetableConflictDetector`) were caught and fixed via 3 consecutive re-runs against the same Postgres container. This closes the last item the backlog's own status line had flagged as blocking production-safety, alongside real auth (same day, separately). BuzzMe's Open Question 1 (DPID↔Principal identity mapping) also resolved same day: a lookup call to Principal (not a DPID-side cross-reference or Principal-minted ids) — `StudentProfile.externalRef` confirmed not reusable (load-bearing for `AdmissionsService`'s duplicate-enrolment check), so a new dedicated field + reverse-lookup route is the proposed shape; not yet built, FiSH+ER's own to scope. |
| 2026-09-21 | BK-REG-5 added (DPID identity linkage, BuzzMe UC-20 follow-on) — Femi: fold into backlog before continuing. **WEB frontend scaffold work (BK-PLT-2's "shared nav chrome" half, BK-NFR-6) handed off to the dedicated `FiSH+ER WEB` thread same day** rather than built inline here — this backlog stops tracking that item's implementation detail going forward, only its dependency relationship to backend items owned here. |
| 2026-09-21 | BK-REG-5 closed same day (`7472cb3`) — `dpidIdentityId` on `StudentProfile`, `V9` partial unique index, `GET /schools/{schoolId}/students/by-dpid-identity/{identityProfileId}` returning only `studentId`. Also committed `ER/Principal/docs/` + `README.md` to the top-level FiSH repo for the first time (`2ee0b93`) — this whole backlog and its siblings had been sitting untracked locally since 2026-09-17. BK-ATT-6's remaining gap is now narrowly scoped to BuzzMe's own side only: the real `PrincipalAttendanceGateway`/`PrincipalStudentDirectory` HTTP implementations and the mobile/BLE client - nothing further blocks on FiSH+ER. |
| 2026-09-21 | BuzzMe confirmed BK-REG-5's contract matches their real implementation (`buzzme#4`, `b893f6a`) — `PrincipalStudentDirectory`/`PrincipalAttendanceGateway` built and merged against it, no changes needed. BK-ATT-6 is now fully closed on FiSH+ER's side; only BuzzMe's own credential-issuance flow (populating `dpidIdentityId`) remains before UC-20 works end-to-end for a real student. BK-CMP-1 closed same day (`20215d7`), see its own row above. |
| 2026-09-21 | BK-CMP-2 closed (`34f591c`): grep-driven audit across every `safeguardingFlags`/`medicalNotes` touch-point. `listStudents()` had no `ErPrincipal` parameter and no masking at all (unused by any route today, but a landmine); fixed to match `getStudent()`'s masking. `studentsByExternalRef()` checked and found already safe at both its call sites — documented internal-only, no code change needed. |
| 2026-09-21 | BK-REG-6 added and closed same day (`75dfaf2`) after BuzzMe surfaced the gap building real credential issuance (`buzzme#5`): BK-REG-5 only built the read-side lookup, nothing could actually populate `dpidIdentityId`. New `POST /schools/{schoolId}/students/{studentId}/dpid-identity`, gated `canManageRegister` (human, not the DPID service account — answers BuzzMe's own open question on who initiates this). UC-20 is now fully closed on FiSH+ER's side for both read and write; only BuzzMe's own `linkIdentity()` wiring and the mobile/BLE client remain, both entirely BuzzMe's own. BuzzMe independently verified the gating decision against their own credential-issuance SRS (UC-3) and confirmed it's correct — the remaining gap (how a human operator's own session token flows through BuzzMe's inbound HTTP layer) is entirely BuzzMe's own, nothing further needed here. |
| 2026-09-21 | BK-CLS-3 closed (`3ff7204`), continuing the explicit dependency-ordered work-through. See its own row above. |
| 2026-09-21 | BK-ADM-5 closed (`f7440df`): offer letters + guardian accept/decline, adding a real `DECLINED` terminal status. See its own row above. Next in the explicit order: BK-CUR-1. |
| 2026-09-21 | BK-CUR-1 closed (`10b31c7`), completing the explicit dependency-ordered pass Femi asked to work through in order: BK-CMP-2, BK-CLS-3, BK-ADM-5, BK-CUR-1 all done same day. Epic 5b (Curriculum) stays otherwise parked — BK-CUR-2/3/4 still wait on this item plus O1's SPI/TPI formulae, unchanged. |
