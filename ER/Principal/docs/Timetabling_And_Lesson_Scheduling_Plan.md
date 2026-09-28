# Timetabling & Lesson Scheduling — full build-out

**Status:** approved 2026-09-27, in progress. Backend owned by this session (+ER), frontend by EA, infrastructure/config management by CM.

## Context

BK-CLS-1/2 ("Classes, sections, timetables CRUD" / "Assign teachers, detect conflicts") sat in `The_Principal_Backlog.md` as fully-open Musts, but W1 (`254bfd0`) already built and tested real weekly-recurrence scheduling and conflict detection — the backlog just never reflected it (corrected same day this plan was written). What's genuinely missing for a *usable* timetabling feature, verified by reading the actual code:

- **No timetable read/view API at all** — one write route (`POST /schools/{schoolId}/timetable/lessons`) exists; nothing lists it back.
- **No `Room` entity** — `roomId` is a bare nullable string, no catalogue, no capacity.
- **No `Term`/`AcademicPeriod` entity** — Curriculum's `academicYear`/`term` are free strings compared by equality (backlog Open item **O6** — Curriculum and Assessment already can't reconcile their own period identifiers; timetabling is a third consumer of the same missing concept).
- **No explicit teacher-subject-assignment record** — a teacher's subject is only ever implicit in whatever `LessonSlot`s reference their `teacherId`; nothing validates a teacher is actually assigned to teach a subject before a slot is created.

## Recommended approach

**Task 0 — Timetable read + delete routes (zero new dependencies, do first).**
`GET /schools/{schoolId}/timetable/lessons` (list, same no-query-param/no-pagination convention as `GET /schools/{schoolId}/students`) and `DELETE /schools/{schoolId}/timetable/lessons/{lessonSlotId}`, both gated by the existing `ErPrincipal.canManageTimetable()`. Needs nothing new (`LessonSlot`/`LessonSlotsTable`/`SchoolStore.lessonsForSchool`/`lessonById` already exist) — this is what unblocks EA's frontend work, sequenced first.

**Task 1 — `Room` aggregate (independent, parallel with Task 2/3).**
New `domain/classroom/Room.kt` (id, schoolId, name, capacity: Int?), `RoomsTable` (Flyway `V23`), `RoomStore` port + `InMemoryRoomStore`/`ExposedRoomStore`, `POST`/`GET`/`DELETE /schools/{schoolId}/rooms` routes — same layering `StaffAssignment` already establishes. Once built, `LessonSlot.roomId` gets validated against real `Room` rows instead of being a free string (Task 4).

**Task 2 — `Term`/`AcademicPeriod` aggregate (independent, parallel with Task 1/3).**
New `domain/platform/AcademicPeriod.kt` (id, schoolId, academicYear, termNumber or name, startDate, endDate: LocalDate) — the shared type Open item O6 already flags as needed. `AcademicPeriodsTable` (Flyway `V24`), store + `POST`/`GET /schools/{schoolId}/terms` routes. **Deliberately scoped to the new type only** — retrofitting Curriculum's/Assessment's existing free-string fields onto this type is separate migration work (Task 5), not bundled here.

**Task 3 — `TeacherSubjectAssignment` (independent, parallel with Task 1/2).**
New `domain/staff/TeacherSubjectAssignment.kt` (teacherId, schoolId, subjectCode). Store + `POST`/`GET`/`DELETE /schools/{schoolId}/teachers/{teacherId}/subjects` routes. Deliberately **not** building a full availability-calendar alongside this — the existing conflict detector already prevents double-booking, the actual load-bearing constraint; an availability-window model is parked, not guessed, until something concretely needs it.

**Task 4 — Wire Room/Term/TeacherSubjectAssignment into LessonSlot creation (depends on Tasks 1-3).**
`LessonSlot` gains a nullable `termId`. Slot creation validates: `roomId` (if set) references a real `Room` in the same school; `teacherId` has a `TeacherSubjectAssignment` for the slot's `subjectCode`. Both additive validations on the existing `POST` route, not a new one.

**Task 5 — Reconcile Curriculum/Assessment's free-string term fields against `AcademicPeriod` (depends on Task 2, real follow-on, not blocking).**
Closes O6 for real. Timetabling doesn't need this to ship; whoever eventually builds real (non-placeholder) SPI/TPI (BK-ASS-5/6) will need it done first.

## Explicitly out of scope for this plan

**Gating service consumption (lessons, library, other school services) on guardian fee status** - real requirement, direct instruction 2026-09-27, deliberately sequenced as a separate follow-on plan *after* this one ships, not folded in here. Tracked as `BK-FEE-6` in `The_Principal_Backlog.md`. Needs its own design pass (which services are gate-able, what "behind on fees" means precisely, what "restricted" means operationally) once this plan's Tasks 0-5 are done.

## Coordination

Three-way split: **this session (+ER)** — backend (above); **EA** — frontend timetable view (grid by teacher/room/class-section, built against Task 0's read API); **CM** — infrastructure/config management (reviewing/applying the new Flyway migrations, bundled in SchoolAdmissions' own deploy, not a separate Terraform apply; flagging if the ongoing shared-RDS connection-capacity work should factor into sizing).

## Critical files

- `ER/Principal/SchoolAdmissions/src/main/kotlin/.../domain/classroom/Room.kt` (new), `domain/platform/AcademicPeriod.kt` (new), `domain/staff/TeacherSubjectAssignment.kt` (new)
- `.../domain/classroom/LessonSlot.kt` — Task 4's additive validation
- `infrastructure/persistence/Tables.kt` — three new table objects
- `infrastructure/persistence/migrations/V23__*.sql`, `V24__*.sql`, and a third for `TeacherSubjectAssignment`
- `infrastructure/web/Application.kt` — new routes, reusing `requireSchoolAccess`/`ErPrincipal.canManageTimetable()` conventions
- `The_Principal_Backlog.md` — update as each task closes, same convention as every other entry

## Verification

- Task 0: unit test confirming list returns all slots for a school (not other schools'), delete removes a slot and a second delete 404s; manual `curl` against a real deployed instance once shipped.
- Tasks 1-3: unit + real-Postgres integration tests per new store, same 3x-rerun convention this codebase already uses.
- Task 4: extend conflict-detector-adjacent tests to cover the two new rejection paths (unknown room, teacher not assigned to subject); confirm existing conflict-detection tests still pass unchanged.
- End to end: EA's frontend view against Task 0's real API is the actual product-level verification.

## Change log

| Date | Change |
|------|--------|
| 2026-09-27 | **Task 4 done - this plan's critical path is now complete (Tasks 0-4).** New `TimetableService` (`application/TimetableService.kt`) validates `roomId` (must reference a real `Room`) and teacher-subject assignment (must have a `TeacherSubjectAssignment` for the slot's subject) **before** delegating to `SchoolStore.upsertLesson()`'s own existing conflict-detection - deliberately a new service, not added inside the store method itself, so the ~13 existing test call sites across 6 files that predate Room/TeacherSubjectAssignment entirely needed zero changes (confirmed: full suite green, unchanged, on a fresh rerun). `LessonSlot` gained a nullable `termId` (`V26` migration), not validated against a real row yet (same "may not be adopted" reasoning `roomId` had before Task 1). `SCHOOL_ADMIN` bypasses both new checks (mirrors `CurriculumService.scheduleLesson`'s own precedent) - `TIMETABLER` does not. 8 new `TimetableServiceTest` tests. **Real rollout flag, not silently glossed over**: any school with existing live timetable data has zero `TeacherSubjectAssignment` rows the moment this ships - the next slot create/edit for a non-admin caller will fail until that school's teachers' subject assignments are seeded. Same bootstrap shape as BK-PLT-2's "first SCHOOL_ADMIN is a manual DB seed." Needs a seeding step before/alongside deploy, not assumed away. |
| 2026-09-27 | **Tasks 2 and 3 done, in parallel.** `AcademicPeriod` (`domain/platform/AcademicPeriod.kt`: id, schoolId, academicYear, termNumber, startDate/endDate - real dates, closes O6 at the type level) + store + `AcademicPeriodsTable` (`V24`) + `POST`/`GET /schools/{schoolId}/terms`. `TeacherSubjectAssignment` (`domain/staff/TeacherSubjectAssignment.kt`: id, schoolId, teacherId, subjectCode, idempotent assign) + store + `TeacherSubjectAssignmentsTable` (`V25`) + `POST`/`GET`/`DELETE /schools/{schoolId}/teachers/{teacherId}/subjects`. Both wired into `AppFactory.AppServices`, both gated `canManageTimetable`. 7 + 6 new unit tests, 2 + 3 new integration tests (skip without DB creds). Full suite green (fresh re-run, not cached). Only Task 4 (wiring Room/Term/TeacherSubjectAssignment validation into LessonSlot creation) remains before this plan's critical path is done; Task 5 is a separate, non-blocking follow-on. |
| 2026-09-27 | BK-FEE-6 added (gate service consumption on fee status) - direct instruction, deliberately parked as a follow-on to this plan, not folded in. See `The_Principal_Backlog.md`. |
| 2026-09-27 | **Task 1 done.** New `Room` aggregate (`domain/classroom/Room.kt`: id, schoolId, name, capacity?) + `RoomStore` port + `InMemoryRoomStore`/`ExposedRoomStore` + `RoomsTable` (Flyway `V23`) + `POST`/`GET`/`DELETE /schools/{schoolId}/rooms` routes, gated `canManageTimetable`. Wired into `AppFactory.AppServices`. 9 unit tests + 3 real-Postgres integration tests (skip without DB creds, same convention as every other store here). Full suite green. |
| 2026-09-27 | **Task 0 done.** `GET /schools/{schoolId}/timetable/lessons` (list, unfiltered/unpaginated, same convention as `GET /schools/{schoolId}/students`) and `DELETE /schools/{schoolId}/timetable/lessons/{lessonSlotId}` (204/404), both gated `canManageTimetable`. New `SchoolStore.deleteLesson()` (both InMemory + Exposed). 5 new tests (`SchoolStoreLessonListAndDeleteTest.kt`) - caught and fixed one real bug in the tests themselves along the way: `lessonsForSchool`'s return order isn't guaranteed (backed by a `HashMap`), so an order-sensitive assertion was flaky depending on JVM/hash state - fixed to an order-insensitive check before it could land as a flaky test. Full suite green (234 tests). EA notified this is now live to build against. Tasks 1-3 (Room/AcademicPeriod/TeacherSubjectAssignment) next, in parallel. |
| 2026-09-27 | Plan written and approved. Backlog corrected same day (BK-CLS-1/2 reclassified from open Must to Partially done). Coordination messages sent to CM and EA. Task 0 starting. |
