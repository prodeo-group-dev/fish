# Gap Analysis: BuzzMe's School Attendance SRS vs. SchoolAdmissions

**Source document:** `SRS-School-Attendance-RFID-Bluetooth-v1.0.docx` (Document ID `SRS-ATT-001`, v1.0, dated 2026-09-21, status "Draft for review"), supplied by Femi 2026-09-21/22.
**Reviewed by:** +ER Education session, against the live SchoolAdmissions codebase (not memory) as of 2026-09-22.
**Purpose:** Femi asked for this to be read and analysed, since BuzzMe is being built around it to serve FiSH+ER/SchoolAdmissions.
**Update, 2026-09-22:** independently cross-checked by both the "BuzzMe peer-to-peer payment system" and "Route to Market - FiSH, FiSH+ER BuzzMe" sessions — see [Peer verification](#peer-verification-2026-09-22) below. **Correction to the headline finding as originally written:** the standalone-vs-integrated question below was not actually open — it was decided directly on 2026-09-21 ("Both": DPID's attendance vertical is a standalone, sellable product, with SchoolAdmissions as its first/reference integration, not a hypothetical deployment target). The SRS's vendor-neutral framing is by design, not an oversight needing correction. The real remaining question is narrower — see Peer verification.

## Headline finding

**The SRS never mentions FiSH, SchoolAdmissions, The Principal, DPID, Prodeo, or BuzzMe by name anywhere in its 383 lines**, and its own phased-delivery plan (§11) puts MIS integration in **Phase 3 ("Depth")**, after a self-contained Phase 1 ("Core") that ships its own admin web app, its own register/timetable data, and its own reports. Read literally, this is a vendor-neutral SRS for a **standalone commercial attendance product** — the kind a school could buy off the shelf and bolt onto any MIS (the glossary names SIMS/Arbor/Bromcom as reference examples) — not a spec for a thin capture layer that calls into an existing system of record.

That's a real mismatch with what's actually been built and is already live: BuzzMe's own recent updates this session described "the entire DPID↔Principal loop (identity resolution, attendance marking, credential issuance, linking) built and tested end to end," using the exact ownership split negotiated for UC-20 — BuzzMe owns credential verification and tap capture, SchoolAdmissions owns lesson resolution and is the system of record for the mark itself (`POST /schools/{schoolId}/attendance/auto`, `LessonSlotResolver`, `AttendanceService.mark()`). That integration is the Phase-3-deferred capability this SRS describes — already done, months ahead of the SRS's own schedule.

**Originally written as an open question here — since resolved, see [Peer verification](#peer-verification-2026-09-22):** the answer is "both." DPID's attendance vertical is a standalone, sellable product (which is why the SRS is deliberately vendor-neutral, SIMS/Arbor/Bromcom named as real peers, not placeholders), *and* SchoolAdmissions is its first, reference integration. §11's Phase-3 MIS-connector framing isn't a mistake needing correction — it describes the general product roadmap for schools with no existing MIS, not the reference deployment specifically, which is already integrated today. The real open question this reframes to is narrower: how does DPID's "own primary store" mode (a real requirement for the sellable-product market) coexist with SchoolAdmissions already being the system of record in the reference deployment, without duplication risk *there* specifically?

## Where §7's data model would duplicate what SchoolAdmissions already owns

§7 ("Data requirements") lists logical entities: `Person`, `Credential`, `Reader`, `Device`, `AcademicGroup`, `TimetableSlot`, `Register`, `Mark`, `TapEvent`, `AuditEvent`. Four of these map almost 1:1 onto real, already-built, already-deployed SchoolAdmissions aggregates:

| SRS entity | SchoolAdmissions equivalent (real, live) |
|---|---|
| `Person` | `StudentProfile` (`domain/student/StudentModels.kt`) — bio, guardians, class, medical/safeguarding flags |
| `AcademicGroup` | `ClassSection` (class sections + membership via `StudentProfile.classSectionId`) |
| `TimetableSlot` | `LessonSlot` (`domain/classroom/TimetableConflictDetector.kt`) — classSectionId, teacherId, room, day, time, subject |
| `Register` / `Mark` | `AttendanceRecord` / `AttendanceCode` (`domain/attendance/AttendanceModels.kt`) |

§3.3's own architecture list hedges this correctly — "Timetable and class membership store, **or sync from MIS**." As confirmed below, this isn't ambiguous in the reference deployment: SchoolAdmissions already is that MIS, already integrated, today. The table above stays valid evidence for a real, narrower risk: if DPID's general "own primary store" deployment mode (built for the sellable-product market, schools with no MIS) isn't kept cleanly separable from the reference deployment's config, these four entities could still end up duplicated for FiSH's own schools specifically — not because the architecture question is unsettled, but because a multi-tenant/deployment-mode boundary hasn't been designed yet.

## Where the SRS is legitimately BuzzMe's own domain, no conflict

Not everything here overlaps. These are squarely BuzzMe/device-side concerns that SchoolAdmissions has no reason to own, and nothing here conflicts with what's built:

- Reader pairing, HID vs. BLE capture modes, debounce, offline tap queueing (§4.2, §3.4)
- The `ReaderPort` abstraction unifying HID/BLE (§8.1) — good design instinct, matches this project's own "narrowest interface, own detail internal" convention
- Card/credential enrolment workstation flow (§4.1) — BuzzMe already owns this per today's `IssueCredentialUseCase`/`linkIdentity()` work
- Canonical UID normalization (§7, NFR-40) — pure capture-layer concern

## Concrete gaps on SchoolAdmissions's own side, verified against the real code

Independent of the architecture question above, several SRS requirements assume SchoolAdmissions capabilities that were checked directly and **do not exist yet**:

- ~~No photo field anywhere~~ — **closed, 2026-09-22 (`a06ac09`).** `StudentProfile.photoUrl` now exists (a reference URL, not upload/binary storage — that mechanics decision stays open). FR-50 (photo challenge) and UC-6 depended entirely on this; BuzzMe's own client-side use of it is still unbuilt.
- **No "unexpected tap" handling — it's a hard failure today, not a branch.** `AttendanceService.mark()` (line 70-72) does `require(student.classSectionId == classSectionId) { "class section mismatch" }` — a tap for a student not in the expected class section throws and rejects outright. FR-33 wants three options (wrong class / send to office / add as visitor) instead of a bare error.
- **Mark codes are a closed 3-value enum, and BK-ATT-2 is exactly this gap.** `AttendanceCode` is `PRESENT | ABSENT | LATE` only — the parse-failure message literally says *"gov codes BLK"*. §4.4's FR-36 table (P/L/N/I/M/C/V/B/E) is a real, concrete candidate to unblock this — this is almost certainly the same "newer attendance SRS" BuzzMe flagged earlier this session as a candidate for BK-ATT-2's official code list. Worth confirming and formally adopting.
- **Safeguarding masking is all-or-nothing, not the three-state visibility FR-53 wants.** Today `canAccessSafeguarding()` either returns the real flag value or `null` — a teacher without the role sees nothing, not even that a flag exists. FR-53 wants a middle tier: a discreet indicator that *something* is flagged, without exposing its content, to any teacher taking that register. That's a genuinely new access-control shape, not a tweak.
- **No campus presence concept at all.** FR-20/21/22/23 (gate tap, on-site roll, late threshold) are entirely new scope — `AttendanceRecord` is lesson/session-scoped only, with no notion of arrival/departure or "who is on site right now." If this scope is wanted, it needs a new SchoolAdmissions capability, not an extension of the existing attendance record shape.
- **No roster/photo-tile endpoint for a register screen.** UC-1/FR-31 describe the teacher app showing a class's students with photos and current marks — nothing in SchoolAdmissions returns a class roster shaped for that UI today. Note this is the same shape of "scope a list to what this teacher is actually assigned to teach" question BK-CUR-4 just settled for the curriculum roadmap (via real `LessonSlot` lookups) — the same pattern would apply here.

## Things worth taking at face value, not re-litigating

- **NFR-32's stance on UID security** ("UID knowledge is not authentication; don't rely on card secrecy, photo challenge is the real control") is correct and well-reasoned given MIFARE Classic clonability — no notes.
- **NFR-33/34 (DPIA required before go-live, defined retention schedule)** are real compliance obligations this project hasn't formally addressed yet. SchoolAdmissions is already flagged elsewhere as "not yet safe for real school data" — this SRS is a concrete reminder that a DPIA is a real go-live gate, not just a security-hardening nice-to-have.
- **§10's acceptance criteria are good, specific, and testable** ("a teacher cannot download the whole-school photo roll" is a real RBAC test SchoolAdmissions could run today against its existing masking, once a roster endpoint exists).

## Recommendation

Before BuzzMe (or anyone) starts building against this SRS as written:

1. ~~Get a direct answer on the standalone-vs-integrated question~~ — **already answered ("both"), see Peer verification.** ~~Superseded by the narrower deployment-mode-boundary question~~ — **that's now settled too, direct instruction, 2026-09-22: "The Principal is its education MIS."** Not "a" reference integration among several — for the FiSH deployment specifically, SchoolAdmissions unambiguously *is* the MIS DPID delegates to. DPID's "own primary store" mode stays real for the general sellable product's *other* future deployments (schools with no existing MIS), but it is not an open question for this deployment — no boundary-design work is needed here, because there's no ambiguity to bound.
2. ~~§11's phasing needs correcting~~ — **not needed.** The SRS's vendor-neutral framing and Phase-3 MIS-connector placement are deliberate product-roadmap choices, not a doc that failed to account for FiSH. No correction required.
3. **Formally propose FR-36's mark-code table for BK-ATT-2** — this looks like the real unblock that item has been waiting on.
4. **Scope campus presence (FR-20-23) as new, explicit SchoolAdmissions work if wanted** — don't let it get built silently inside BuzzMe as a parallel data store.
5. ~~Decide whether photo storage belongs on `StudentProfile` or is BuzzMe's own cache~~ — **done, 2026-09-22 (`a06ac09`).** `StudentProfile.photoUrl` (a reference URL, not upload) added, visible to anyone who can see the student, settable via `POST /schools/{schoolId}/students/{studentId}/photo` or CSV import (`photo_url` column). BuzzMe's own domain still has nothing photo-related — this only closes the SchoolAdmissions-side half of FR-50/UC-1.
6. **Decide who creates a brand-new student's first `IdentityProfile`** — see below, the single largest open item on BuzzMe's own side.

## Peer verification, 2026-09-22

Both peer sessions read the full document and checked their own side directly rather than taking the findings on faith — folding their results in here rather than leaving them scattered across chat.

**BuzzMe confirmed zero split-brain risk in what's actually built today.** Its entire persisted schema is two tables (`identity_profiles`, `credentials`, `V1__baseline.sql`) — no `AcademicGroup`, `TimetableSlot`, `Register`, `Mark`, or school-scoped `Person` data anywhere in DPID's own store. Every attendance mark, lesson slot, class section, and student record lives only in SchoolAdmissions, unchanged. The §7 table above is accurate about what *would* duplicate if Phase 1 were built literally as the SRS's standalone framing implies — not a description of anything that currently exists.

**BuzzMe's first read of the architecture question (superseded, kept for the record):** BuzzMe initially described this as a genuinely open question — building on "DPID stays identity/credential-only, permanently delegates attendance-of-record to whichever MIS is present," but never pinned down as a hard rule — and proposed escalating it to Femi as unresolved.

**Route to Market corrected this immediately after**, having found the actual decision: the standalone-vs-integrated question **was already asked and answered directly on 2026-09-21**, in a session this analysis didn't have visibility into. The answer is **"both"** — DPID's attendance vertical is confirmed a standalone, sellable product, with SchoolAdmissions as its first/reference integration, not a hypothetical deployment target. That's why the SRS reads vendor-neutral throughout (SIMS/Arbor/Bromcom named as real peers, not placeholders) — by design, not an oversight, and not a document that needs correcting to name FiSH explicitly.

Given "both" is confirmed, Route to Market reframed what's actually still open: **how does DPID support "own primary store" mode — a real requirement for a school with no existing MIS, which is most of the sellable-product market — without that becoming duplicate-entity risk for the reference deployment specifically, where SchoolAdmissions already is the system of record?** The §7 duplication table above is still valid evidence for that narrower question; it just isn't evidence that the SRS's phasing or neutrality needs fixing. This document's headline finding, recommendation items 1-2, and the §7 section have been corrected above to reflect this rather than left contradicting it.

**Route to Market cross-referenced BuzzMe's own newer scoping doc** (`docs/Enrolment_Attendance_Client_Requirements.md`, dated 2026-09-21 — the same day as the SRS) and confirmed it **already treats the DPID↔Principal integration as done** for the reference deployment specifically: a thin client over SchoolAdmissions's live APIs, SchoolAdmissions as login provider and system of record, explicitly no duplicate entities. Consistent with "both" — the reference integration is already built correctly; the sellable-product deployment mode is the part without an explicit boundary yet.

**New open item surfaced by that same doc, not visible from this side:** nothing creates a *new* `IdentityProfile` today. `IssueCredentialUseCase` requires one to already exist — neither side has decided how a brand-new student gets their first `IdentityProfileId`. Flagged there as the single largest open item on BuzzMe's own side. Same class of gap as the standalone-vs-integrated question: a real design decision needing a direct answer, not an assumption from either side.

**Also independently confirmed by Route to Market:** the same photo-challenge gap (FR-50/UC-6) this document flags — zero photo concept anywhere in DPID's own domain either, deferred the same way.

The four SchoolAdmissions-side gaps (photo field, safeguarding three-state masking, campus presence, roster endpoint) remain this side's own to prioritize, independent of how the architecture question resolves — none of them are blocked on Femi's answer.

**Confirmed by direct instruction, 2026-09-22: "The Principal is its education MIS."** Settles the deployment-mode-boundary question raised above — for the FiSH deployment, there's no "own primary store" ambiguity to design around; SchoolAdmissions is unambiguously the system of record DPID delegates to, full stop. That mode stays real for DPID's general sellable-product roadmap elsewhere, but doesn't touch this integration.
