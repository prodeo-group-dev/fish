# Education Runtime — Local-First Sync Architecture Design

**Date:** 2026-10-02
**Status:** Design, not yet built.
**Supersedes:** the "scope to 1-2 workflows, defer the rest" framing originally in `docs/Education_Runtime_MVP_Definition.md` §3, corrected 2026-10-01 — see that doc for the decision record.

## 1. Scope and non-goals

**In scope for this pass (Education Runtime's backend)**: the server-side contract that makes a local-first client possible — entity classification, conflict-resolution policy, device registration/trust, the sync API (delta pull + batched push with idempotency), provisional-ID reconciliation, and the offline receipt-number-range mechanism FIN-INT-013 needs.

**Explicitly out of scope here, for whoever builds the actual client**: the embedded local-database technology choice for Android/PWA (SQLite via Room, IndexedDB via Dexie/RxDB, WatermelonDB, a CRDT store, etc.), the client-side UI/UX of sync status and conflict surfacing, and the actual mobile/PWA app build itself. This backend repo (`fish-education-runtime`) doesn't own the client — the design below is deliberately client-agnostic so whichever client gets built (and whoever builds it) implements against a contract, not against a specific embedded-DB API.

**Why design the backend side first, not the client**: the hard, foundational decisions — what conflict resolution actually means per entity, how provisional IDs get reconciled, what a device is trusted to write — are server-contract decisions. Getting those wrong is expensive to unwind regardless of which client technology eventually consumes them; getting the client's local-DB choice wrong is comparatively cheap to redo later. This mirrors the correction that produced this design pass: don't retrofit the hard part after the easy part is already built.

## 2. Entity classification

Every entity in Education Runtime's current domain model, classified by whether a registered offline device should be able to create or mutate it while disconnected. This is the first real design decision this doc makes — not every write needs to be offline-capable, and treating everything as offline-capable would be over-engineering exactly the kind of thing this project's own conventions warn against.

### Offline-write-capable (Must, per the v0.1 spec's NFR-OFF-001)

| Entity | Why it must work offline | Current write path |
|---|---|---|
| `AttendanceMark` (attendance) | The daily register is the single most-cited offline-blocking workflow in the spec — a Form Master takes it every single school day, often before connectivity is confirmed. | `AttendanceService.mark()` |
| `StudentProfile` (admission capture only) | New-student admission at a rural campus can't wait for a connectivity window — the spec's own UC-01 A3 explicitly describes "saved on the device with a provisional admission number, finalised on sync." | `AdmissionsService.submit()` / `SchoolStore.putStudent()` |
| `GradeEntry` (CA/exam scores) | Teachers enter scores "online or offline" per UC-04 step 3 — a real daily-use workflow at the classroom level, same connectivity profile as attendance. | `AssessmentService.enterGrade()` |
| Gate/visitor log entries (not yet built — BK-CMP-5) | Gate staff logging is continuous, real-time, and the gate is often the least-connected point on a campus. | Not built yet |
| Pickup verification (not yet built — BK-CMP-6) | Same gate-side connectivity profile as the visitor log; a failed pickup check must still be enforceable offline. | Not built yet |
| Fee cash receipts (not yet built — BK-FIN-10 / FIN-INT-013) | Cash payment at the bursary can't be refused because the network is down; the spec specifically calls out pre-allocated offline receipt-number ranges for this. | Not built yet (depends on Epic 13's SOP migration) |

### Server-authoritative only (never written offline)

Everything else — confirmed by reading the actual domain model (`domain/` package listing, 2026-10-02): `School`, `AcademicPeriod` (Room/Term config), `Room`, `TeacherSubjectAssignment`, `Teacher` (directory), `StaffAssignment` (RBAC), `CurriculumTopic`/`TopicProgressEntry`/`ScheduledLesson`, `ClassTransfer`, `GuardianAccount`/fee schedules (`FeeModels.kt`), `AdmissionApplication` status transitions *after* initial submission (approval workflow, not daily-use).

**Why these stay server-only**: they're either (a) setup-time configuration done by a System Administrator who can reasonably be assumed to have connectivity at setup time (terms, rooms, curriculum maps, teacher assignments), or (b) approval/workflow steps that are inherently sequential and low-frequency (admission approval, class transfer), not classroom-floor daily operations. Forcing these offline-capable too would mean building conflict resolution for things that don't need it — the "local-first by default" correction means "the workflows that actually run on the classroom/gate/bursary floor," not "literally everything."

**Open, not decided here**: whether this classification needs revisiting once boarding (ER-BRD, Phase 2) and the fuller exam-registration workflow (ER-EXM, Phase 2) are built — both likely add their own offline-capable entities (roll call, exeat sign-out/sign-in) following the same pattern, but that's this design's job to extend later, not to pre-guess now for scope that isn't being built yet.

## 3. Device registration and trust model (NFR-SEC-006)

New aggregate: `RegisteredDevice`.

```
RegisteredDevice(
  id: String,                 // server-generated
  schoolId: SchoolId,
  subjectId: String,          // the staff member the device is registered to
  deviceLabel: String,        // human-readable, e.g. "Form Master Tablet - JSS1A"
  status: ACTIVE | REVOKED,
  registeredAt: Instant,
  registeredBy: String,       // who approved registration - never self-service
  lastSyncAt: Instant?,
  lastSyncCursor: String?     // see §4
)
```

- Registration is staff-initiated, admin-approved — mirrors the existing `StaffAssignment` precedent of never minting access in-process (`AdmissionsService.enrol()`'s own "never mint register rights in-process" rule extends naturally here: a device doesn't grant itself offline write access, a `SCHOOL_ADMIN`/`REGISTRAR` does).
- Revocation is immediate and server-enforced: every sync-push request checks `RegisteredDevice.status == ACTIVE` before accepting any write, closing the loop on "remote revocation/wipe of offline data" (NFR-SEC-006) — the device can still hold local data after revocation (nothing can force-wipe an offline device), but the server simply stops accepting its writes and stops serving it pulls.
- PIN/biometric app-lock is a client-side concern (out of scope here, §1).
- A device is scoped to one `subjectId`, not shared across staff — avoids needing per-write attribution reconciliation on top of per-device trust.

## 4. Sync protocol

### Pull: delta changes since a cursor

```
GET /schools/{schoolId}/sync/changes?deviceId={id}&since={cursor}
```

Returns every record the device's `subjectId` is scoped to see (same RBAC/field-masking rules as the existing online routes — `canAccessSafeguarding()`, arm/campus scoping — apply identically here; sync is not a backdoor around existing access control) that changed since `cursor`, plus a new cursor to use next time. `cursor` is an opaque, monotonically-increasing server-side sequence token, not a timestamp — timestamps are unsafe for this because of clock skew across devices and the platform's own existing `NFR-OFF-006` requirement to record server time at sync rather than trust the device clock.

### Push: batched writes with idempotency

```
POST /schools/{schoolId}/sync/push
```

Body: an array of locally-queued write operations, each carrying:
- `clientOpId` (client-generated UUID) — the idempotency key. A retried push with the same `clientOpId` is a no-op if already applied, exactly matching this codebase's own existing outbox-idempotency pattern (`SopEventEnvelope`/`OutboxSopEventPublisher`) rather than inventing a new one.
- `entityType` + `provisionalId` (client-generated, for creates) or `entityId` (server-assigned, for updates to an already-synced record).
- `entityVersion` the device last saw (for updates) — used for the conflict check in §5.
- The payload itself (e.g. an attendance mark, a grade entry).

Response: per-operation result — `accepted` (with the final server-assigned `entityId` if it was a create), `conflict` (with the server's current value, for the device to surface for review — never silently discarded), or `rejected` (e.g. device revoked, RBAC failure, validation error).

Processed transactionally per batch, same tenant/permission defense-in-depth every existing service method already applies — sync is a new transport, not a new authorization model.

## 5. Conflict resolution policy, per entity

This is the concrete version of the spec's own §6.3 sketch ("last-writer-wins for contacts, flag-for-review for scores/payments") — resolved per the entities this platform actually has, not left abstract.

| Entity | Policy | Reasoning |
|---|---|---|
| `AttendanceMark` | If the server has no mark for that (student, session) slot yet: accept the device's mark. If the server already has a mark for that slot from a *different* device/user: **conflict, flagged for review** — two people marked the same register differently, a real discrepancy, never silently overwritten. | Matches `ER-ATT-008`'s existing "corrections need a reason, original mark kept" principle, extended to the offline case. |
| `GradeEntry` | If the server has no score for that (student, assessment) yet: accept. If one already exists: **always conflict, never overwrite** — scores are high-stakes and published results are locked (`ER-ASM-004`); a silent overwrite risks exactly the kind of unaudited change that rule exists to prevent. | Stricter than attendance deliberately — grades feed report cards and promotion decisions. |
| `StudentProfile` creates (admission capture) | Provisional ID always gets a real server ID on sync; the duplicate-enrolment check (`AdmissionsService`'s existing dedup logic) re-runs at sync time against server state, not just the device's local view. **If a duplicate is found at sync time, the device's create is held as a conflict for staff review, not auto-merged or auto-rejected.** | Matches the spec's own E4 flow exactly: "server assigns the final number, provisional number retained in history." |
| `StudentProfile` field edits (contacts, health notes, etc. — once ER-CON exists, Epic 11) | Last-writer-wins by field, with the edit recorded in the existing `StudentAuditEntry` history (already versioned) — not a whole-record overwrite. | Contact detail changes are low-stakes and frequent; losing a field edit to a rare true collision is an acceptable, auditable trade-off; losing a grade or a payment is not. |
| Gate/visitor log, pickup verification (once built, BK-CMP-5/6) | **Append-only, no conflict possible** — these are events, not mutable records. Idempotency key (`clientOpId`) alone prevents double-counting a retried submission. | Simplest possible case, deliberately — don't build conflict resolution for something that's structurally a log, not a record. |
| Fee cash receipts (once built, BK-FIN-10) | **Append-only, never conflict-resolved by overwrite.** Receipt numbers come from a pre-allocated range (§7) specifically so two offline receipts can never collide even before either syncs. | A financial record must never be silently merged or overwritten — this is the one category where "never conflict, structurally impossible to collide" is the actual design goal, not a fallback. |

**Deliberately not built in this pass**: a generic, configurable per-entity conflict-resolution engine. Each policy above is specific to what the entity actually means, which is the right level of generality for the five entity types that actually exist — building an abstraction over policies that don't exist yet (boarding roll call, exeat sign-out, once Phase 2 arrives) would be exactly the premature abstraction this project's own conventions warn against.

## 6. Provisional-ID reconciliation

1. Device creates a record offline with a **client-generated provisional ID** (a UUID, prefixed or namespaced by `deviceId` to make collisions across devices structurally impossible even before either syncs — e.g. `device:{deviceId}:{localUuid}`).
2. All offline references to that record (e.g. a `GradeEntry` referencing a `StudentProfile` admitted the same day, offline) use the **provisional ID** locally.
3. On sync push, the server assigns the real ID and returns a `{provisionalId → realId}` mapping in the response.
4. The device remaps every local reference to the provisional ID, then marks the record as synced. Any records still queued (not yet pushed) that reference the provisional ID get remapped before their own push.
5. The provisional ID itself is **never discarded** — kept in the server record's history (mirrors the spec's own "provisional number retained in history" line) so a support investigation can always trace a synced record back to the exact offline write that created it.

## 7. Offline receipt-number ranges (FIN-INT-013 / BK-FIN-10)

A device requests a block of receipt numbers *while online* (e.g. "give me the next 50 receipt numbers for cash receipting"), consumes them locally while offline, and reports usage back on sync. This requires:
- SOP (per the Epic 13 architecture decision — SOP is "FiSH core" for this purpose, not GL directly) to own the actual receipt-number sequence and allocate ranges on request.
- The device never invents its own receipt numbers — it only draws from an allocated range, so two offline devices can never collide even if they're never aware of each other.
- Gaps (allocated-but-unused numbers, e.g. a cancelled transaction) and duplicates (a number used twice, a bug or device-state-loss symptom) are both detected and flagged at sync time, exactly as the spec's own E-flow for this case describes.

**This is explicitly sequenced after Epic 13's SOP migration is underway** — there's no receipt-number sequence to allocate ranges from until invoicing/payment system-of-record actually lives in SOP. Building this piece before Epic 13 would mean allocating ranges against Education Runtime's own soon-to-be-replaced `FeeInvoice` sequence, real throwaway work.

## 8. Backend API surface to build

New, in rough dependency order:
1. `RegisteredDevice` aggregate + store + `POST /schools/{schoolId}/devices` (register, admin-approved) + `DELETE /schools/{schoolId}/devices/{id}` (revoke) + `GET /schools/{schoolId}/devices` (list, for the admin vetting-status-report pattern this codebase already uses elsewhere).
2. A server-side change-sequence mechanism (the `cursor` in §4) — likely a monotonic sequence column added to the tables of every offline-capable entity (§2's first table), read by the delta-pull endpoint. This is the one piece of new, genuinely cross-cutting infrastructure this design needs — not entity-specific.
3. `GET /schools/{schoolId}/sync/changes` (delta pull).
4. `POST /schools/{schoolId}/sync/push` (batched write, idempotent, per-entity conflict policy from §5).
5. The offline receipt-number-range endpoint (§7) — sequenced after Epic 13, not before.

## 9. Recommended build sequencing

1. `RegisteredDevice` + registration/revocation routes (foundational, no dependencies, can start immediately).
2. The change-sequence/cursor infrastructure (§8.2) — needs deciding which entities get it first; recommend starting with `AttendanceMark` alone (the single most-cited offline workflow) rather than all six offline-capable entities at once, proving the pattern on the simplest, lowest-conflict-complexity entity before extending it to `GradeEntry`/`StudentProfile`/the not-yet-built gate-log and receipting entities.
3. Delta pull + batched push, built and tested against `AttendanceMark` end to end (including a real device-simulated offline-then-sync test, not just unit tests against the Kotlin service layer).
4. Extend to `GradeEntry` and `StudentProfile` admission capture once the attendance path is proven.
5. Gate/visitor log, pickup verification, and offline cash receipting follow their own epics' build-out (BK-CMP-5/6, BK-FIN-10) using the now-proven sync pattern, not reinventing it.

This sequencing deliberately does *not* try to build all six offline-capable entities' sync support simultaneously — proving the pattern once, on the entity with the clearest conflict policy (attendance), de-risks the harder cases (grades, admissions) before committing to their own nuances.
