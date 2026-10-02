# Local-First Sync — Build Plan

**Date:** 2026-10-02
**Design reference:** `docs/Education_Runtime_Local_First_Sync_Design.md` — this plan turns that design's §8/§9 into dependency-ordered, buildable tasks.

## Scope

Backend-only (`fish-education-runtime`). Builds the server contract a local-first client syncs against: device trust, delta-pull, idempotent batched-push, and the per-entity conflict policy the design doc already resolved. Proves the pattern end to end on **`AttendanceMark` alone first** before extending to any other entity — deliberately not building all six offline-capable entities' sync support at once (design doc §9's own reasoning: prove the simplest, lowest-conflict-complexity case before committing to grades/admissions' extra nuance).

**Explicitly not in this plan**: the Android/PWA client itself (no session currently owns building it — flagged below, not guessed at), gate/visitor log and pickup verification sync (depend on BK-CMP-5/6, not built yet), offline cash receipting (depends on Epic 13's SOP migration landing first).

## Tasks, dependency-ordered

**Task 1 — `RegisteredDevice` aggregate + registration/revocation/list routes.**
No dependencies — the trust model everything else checks against. New domain class (`id`, `schoolId`, `subjectId`, `deviceLabel`, `status: ACTIVE|REVOKED`, `registeredAt`, `registeredBy`, `lastSyncAt?`, `lastSyncCursor?`), store port + `InMemoryRegisteredDeviceStore`/`ExposedRegisteredDeviceStore`, Flyway migration, `POST`/`GET`/`DELETE /schools/{schoolId}/devices`. Admin-approved, never self-service — mirrors `AdmissionsService.enrol()`'s "never mint register rights in-process" precedent. **Building this now.**

**Task 2 — Change-sequence/cursor column on `attendance_records` only.**
Depends on nothing structurally, but only useful once Task 3/4 consume it — sequenced here so it lands just before the endpoints that need it. A monotonic sequence (not a timestamp — avoids device-clock-skew issues the design doc's §4 already flags), incremented on every insert/update to an `AttendanceMark` row.

**Task 3 — Delta-pull: `GET /schools/{schoolId}/sync/changes`, scoped to `AttendanceMark` only.**
Depends on Task 1 (validates `deviceId` against `RegisteredDevice.status == ACTIVE`) and Task 2 (the cursor it reads). Existing RBAC/masking rules apply identically — sync is a new transport, not a new authorization path.

**Task 4 — Batched-push: `POST /schools/{schoolId}/sync/push`, scoped to `AttendanceMark` only.**
Depends on Task 1 + Task 2. Implements the design doc §5 conflict policy for attendance specifically (accept if no existing mark for that slot; conflict-flag, never overwrite, if a different device/user already marked it) and `clientOpId` idempotency, matching the existing `SopEventEnvelope`/outbox idempotency pattern rather than inventing a new one.

**Task 5 — End-to-end attendance-sync test.**
Depends on Tasks 1–4. Real scenarios: a revoked device's push is rejected; a genuine conflict is flagged, not silently resolved; a retried push with the same `clientOpId` is a no-op; a delta-pull after a push returns the new state with an advanced cursor.

**Task 6 — Extend the proven pattern to `GradeEntry`.**
Depends on Task 5 passing. Same mechanism (cursor column, delta-pull, batched-push), `GradeEntry`'s own stricter conflict policy (always conflict-flag if a score already exists, never the attendance-style "accept if no existing mark" — scores are higher-stakes).

**Task 7 — Extend to `StudentProfile` admission capture.**
Depends on Task 6. First entity needing the full provisional-ID reconciliation protocol (design doc §6) — a *create*, not an update to an existing server record, so this is genuinely the harder case, correctly sequenced last among the three MVP-scoped entities.

**Not scheduled yet, depends on other epics landing first**: gate/visitor log + pickup verification sync (BK-CMP-5/6), offline cash-receipt ranges (Epic 13/BK-FIN-10).

## One open coordination item, not guessed at

No current peer session owns building the actual Android/PWA client that will consume this contract. This plan builds the server side only; **flagging to Femi that the client itself needs an owner assigned at some point** — not decided here, not assumed to be WEB's scope just because WEB is the other FiSH+ER-adjacent session, since a native offline-first Android app is a different skill/stack from WEB's current React PWA work.

## Verification

Each task gets unit tests against the in-memory store (matching every other build in this codebase) plus a real-Postgres integration test for the new `RegisteredDeviceStore`/the new sequence column. Task 5's end-to-end test is the actual proof the sync contract works, not just that each piece compiles in isolation.
