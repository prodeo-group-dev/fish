# Gap Analysis: BuzzMe's School Attendance SRS vs. SchoolAdmissions

**Source document:** `SRS-School-Attendance-RFID-Bluetooth-v1.0.docx` (Document ID `SRS-ATT-001`, v1.0, dated 2026-09-21, status "Draft for review"), supplied by Femi 2026-09-21/22.
**Reviewed by:** +ER Education session, against the live SchoolAdmissions codebase (not memory) as of 2026-09-22.
**Purpose:** Femi asked for this to be read and analysed, since BuzzMe is being built around it to serve FiSH+ER/SchoolAdmissions.

## Headline finding

**The SRS never mentions FiSH, SchoolAdmissions, The Principal, DPID, Prodeo, or BuzzMe by name anywhere in its 383 lines**, and its own phased-delivery plan (§11) puts MIS integration in **Phase 3 ("Depth")**, after a self-contained Phase 1 ("Core") that ships its own admin web app, its own register/timetable data, and its own reports. Read literally, this is a vendor-neutral SRS for a **standalone commercial attendance product** — the kind a school could buy off the shelf and bolt onto any MIS (the glossary names SIMS/Arbor/Bromcom as reference examples) — not a spec for a thin capture layer that calls into an existing system of record.

That's a real mismatch with what's actually been built and is already live: BuzzMe's own recent updates this session described "the entire DPID↔Principal loop (identity resolution, attendance marking, credential issuance, linking) built and tested end to end," using the exact ownership split negotiated for UC-20 — BuzzMe owns credential verification and tap capture, SchoolAdmissions owns lesson resolution and is the system of record for the mark itself (`POST /schools/{schoolId}/attendance/auto`, `LessonSlotResolver`, `AttendanceService.mark()`). That integration is the Phase-3-deferred capability this SRS describes — already done, months ahead of the SRS's own schedule.

**This needs a direct answer, not an assumption on my part:** is this SRS meant to describe what serves FiSH+ER specifically (in which case its scope and phasing should be corrected to build *on* SchoolAdmissions from Phase 1, not defer to it in Phase 3), or is BuzzMe deliberately building a standalone, sellable product where the FiSH integration is just one deployment target? Those are two different builds with very different amounts of duplicated work, and the SRS as written reads like the second one.

## Where §7's data model would duplicate what SchoolAdmissions already owns

§7 ("Data requirements") lists logical entities: `Person`, `Credential`, `Reader`, `Device`, `AcademicGroup`, `TimetableSlot`, `Register`, `Mark`, `TapEvent`, `AuditEvent`. Four of these map almost 1:1 onto real, already-built, already-deployed SchoolAdmissions aggregates:

| SRS entity | SchoolAdmissions equivalent (real, live) |
|---|---|
| `Person` | `StudentProfile` (`domain/student/StudentModels.kt`) — bio, guardians, class, medical/safeguarding flags |
| `AcademicGroup` | `ClassSection` (class sections + membership via `StudentProfile.classSectionId`) |
| `TimetableSlot` | `LessonSlot` (`domain/classroom/TimetableConflictDetector.kt`) — classSectionId, teacherId, room, day, time, subject |
| `Register` / `Mark` | `AttendanceRecord` / `AttendanceCode` (`domain/attendance/AttendanceModels.kt`) |

§3.3's own architecture list hedges this correctly — "Timetable and class membership store, **or sync from MIS**" — which is compatible with treating SchoolAdmissions as that MIS. But nothing in the SRS commits to that reading, and §11's phasing actively contradicts it (sync deferred to Phase 3). If BuzzMe builds its own primary copies of these four entities for Phase 1 "Core" rather than reading them live from SchoolAdmissions's already-existing endpoints, the platform ends up with two systems of record for the same facts (who's in which class, what a student's mark was) — precisely the split-brain problem the DPID↔Principal integration work this session was built to avoid.

## Where the SRS is legitimately BuzzMe's own domain, no conflict

Not everything here overlaps. These are squarely BuzzMe/device-side concerns that SchoolAdmissions has no reason to own, and nothing here conflicts with what's built:

- Reader pairing, HID vs. BLE capture modes, debounce, offline tap queueing (§4.2, §3.4)
- The `ReaderPort` abstraction unifying HID/BLE (§8.1) — good design instinct, matches this project's own "narrowest interface, own detail internal" convention
- Card/credential enrolment workstation flow (§4.1) — BuzzMe already owns this per today's `IssueCredentialUseCase`/`linkIdentity()` work
- Canonical UID normalization (§7, NFR-40) — pure capture-layer concern

## Concrete gaps on SchoolAdmissions's own side, verified against the real code

Independent of the architecture question above, several SRS requirements assume SchoolAdmissions capabilities that were checked directly and **do not exist yet**:

- **No photo field anywhere.** `grep -ri photo src/main/kotlin/` returns nothing. FR-50 (photo challenge — the SRS's primary anti-buddy-punching control) and UC-6 depend entirely on a student photo existing somewhere queryable. This is a real, unbuilt dependency, not a small gap.
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

1. **Get a direct answer on the standalone-vs-integrated question above** — it changes whether §7's four overlapping entities get built as BuzzMe's own primary store (duplication risk) or as thin reads through SchoolAdmissions's existing APIs (no duplication, matches what's already live).
2. If the answer is "integrated, SchoolAdmissions is the MIS," **§11's phasing needs correcting** — the MIS connector shouldn't be Phase 3 when the real integration is already built and live.
3. **Formally propose FR-36's mark-code table for BK-ATT-2** — this looks like the real unblock that item has been waiting on.
4. **Scope campus presence (FR-20-23) as new, explicit SchoolAdmissions work if wanted** — don't let it get built silently inside BuzzMe as a parallel data store.
5. **Decide whether photo storage belongs on `StudentProfile` or is BuzzMe's own cache** before FR-50/UC-6 get built against a field that doesn't exist yet.
