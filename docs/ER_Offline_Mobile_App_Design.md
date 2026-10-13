# The Education Runtime offline mobile app: design pass (F11)

**Status:** DRAFT 1, 2026-10-13. **Design only; nothing is built.** Written by the Education Runtime (+ER) session for task **F11** of the Playbook (Part 4), with WEB to co-own the client side. Femi's decision (D1, 2026-10-13): **"Both. Offline is an App on a mobile device"**, so the school gets online use and an offline **mobile app**. Evidence tags: **[code]** read in `fish-education-runtime` on 2026-10-13, **[design]** an existing design document, **[proposal]** mine, to be decided, **[open]** needs WEB, CM or Femi.

**Relation to existing documents.** `Education_Runtime_Local_First_Sync_Design.md` (the server contract and the per-entity conflict policy, 2026-10-02) and `Local_First_Sync_Build_Plan.md` stay the server-side reference; `EduSys_Separate_App_SPUTO.md` (path versus subdomain, a separate installable web app) stays the hosting reference. **This note adds what neither has: the client.** It does not restate them.

## 1. What the app must do (v1 scope)

| Capability | Offline | Why |
|---|---|---|
| **Take the register** for the teacher's arms and lessons | full | the single most-cited offline workflow (spec NFR-OFF-001) |
| **Enter and correct marks** for the teacher's subject offerings | full | same connectivity profile; marks never silently overwritten |
| **Look up** the teacher's students, classes, timetable, offerings | read | needed to do the two above |
| **Sync status**: a visible queue, per-item state, conflicts surfaced | n/a | no silent loss (NFR-OFF-002, 003) |
| Everything else (admissions, fees, reports, roles, approvals, report-card publication) | **online only**, in the web app | classified server-authoritative in the design |

Out of v1: admission capture offline (spec UC-01 A3: provisional admission number), cash receipts (needs SOP's number ranges, P2), gate and visitor log (P2).

## 2. What the server already gives the app **[code]**

- **Devices:** register, list and revoke (`POST /schools/{id}/devices`, `GET`, `DELETE`); a device is bound to one staff subject; a revoked or unregistered device is refused (`forbidden`) on sync.
- **Attendance:** `GET /schools/{id}/sync/changes` (an attendance change feed with an opaque cursor and `hasMore`) and `POST /schools/{id}/sync/push` (a batch of attendance ops, each with a `clientOpId`; a claim-first idempotency ledger returns the recorded outcome on a replay; a reused id with a different payload is refused).
- **Marks:** `PUT .../offerings/{id}/marks` and `POST .../marks:batch`, each mark with an `opId` (namespaced in the same ledger), a version per cell, a history that is never deleted, and a stale version refused with the current value.
- **Paged reads** for the teacher's offerings and rosters.

## 3. What is missing on the server (the ER backend list for F12) **[proposal]**

| # | Gap | Proposal | Size |
|---|---|---|---|
| S1 | **No change feed for marks, rosters or offerings**; only attendance has a cursor | a version-since read for the teacher's offerings and rosters (or an ETag per roster page) so the app refreshes only what changed | M |
| S2 | **One prefetch bundle** per teacher (my offerings, rosters, scales, structures, class lists, timetable) so a weak link does one call, not forty | `GET /schools/{id}/sync/bundle?deviceId=` with a cursor and size cap | M |
| S3 | The attendance **push body is pipe-delimited text**, fragile for a client | a JSON body (consumer-first, the old stays), with a fixture in `fish-contracts` | S |
| S4 | **Device handshake**: server time, minimum app version, a wipe flag, the late-sync deadline (D4) | `GET /schools/{id}/devices/{id}/handshake` | S |
| S5 | **Per-batch limits and a partial-failure contract** documented and tested | defined in the contract | S |
| S6 | **A shared classroom phone** (one device, several teachers) conflicts with "a device is scoped to one subject" | decision O3 below; if shared devices are needed the model changes (a device holds a list of subjects, writes carry the acting subject) | M |

### 3.1 Order and size (Femi approved the six gaps and the prefetch "sooner than later", 2026-10-13)

| Order | Gap | Why here | Size | Notes |
|---|---|---|---|---|
| **1** | **S2 prefetch bundle** | what the app is useless without, and the biggest win on a weak link (one call, not forty); Femi: "sooner than later" | **M** (3 to 4 days) | one read per device: the teacher's arms, students, offerings (with current mark cells and versions, so offline editing starts from the right version), scales, structures, timetable; a cursor and a size cap; scoped like the online routes (a teacher gets only their own classes and offerings; head roles see more); no safeguarding fields; tests for scoping, paging and a revoked device |
| **2** | **S4 device handshake** | tiny, and gives the app server time, the minimum app version, the wipe flag and the late-sync deadline (D4) before it does anything else | **S** (about 1 day) | can ride on the prefetch response header first and become its own route if needed |
| **3** | **S3 JSON push body** (with a fixture in `fish-contracts`) | the app should not speak a pipe-delimited text format; consumer-first, the old body stays | **S** (about 1 day) | the idempotency ledger is unchanged |
| **4** | **S1 change feed for marks, rosters and offerings** | after the first prefetch the app needs only what changed | **M** (about 3 days) | a version-since read or an ETag per roster page; the marks ledger and cell versions already exist |
| **5** | **S5 limits and partial-failure contract** | documented and tested so the app can size its batches and handle a half-applied batch | **S** (0.5 to 1 day) | |
| **6** | **S6 shared classroom phone** | **not in v1** (open question O3: one device, one teacher); the model change is only needed if Femi wants shared devices | **M**, deferred | |

**Total for v1 on the server (S2, S4, S3, S1, S5): about 9 to 10 days**, my estimate, unproven; S2 and S4 alone, 4 to 5 days, are enough for WEB to start the app against real data. The client (option B, WEB's) is sized by WEB.

## 4. The client, in layers

1. **Local store.** An encrypted database on the device (a SQLite engine with encryption, key in the Android Keystore). Holds only what the person needs: their arms, students, offerings, scales, structures and timetable (**data minimisation**: no other teachers' classes, no safeguarding fields, no fee data). A **sync outbox** table holds every unsent operation with its id, entity, payload, created time and state.
2. **Operation states:** `queued` → `sending` → `applied` | `conflict` | `refused` (never deleted until the person resolves a conflict). **Write first, confirm after**: an operation is committed to the outbox inside the same transaction as the screen change, so a power cut never loses a mark the teacher saw saved (NFR-OFF-007; a write-ahead log).
3. **Sync engine.** On connectivity (and on a manual "sync now"): handshake, push the outbox in order per entity, then pull changes. Retries are safe because every operation carries a stable id the server already de-duplicates. Backoff on failure; resumable batches.
4. **Conflict surfacing.** An attendance conflict (another mark for the same slot) and a marks conflict (a newer cell version) show **both values**, who and when, and ask the teacher to keep one; nothing is overwritten silently (design §5).
5. **App lock and session.** A device PIN unlocks the app; the account's refresh token is kept in the Keystore; **offline, the PIN unlocks the local store and queues work; tokens are refreshed on reconnect** (an access token will have expired during days offline, so the push uses a fresh one). N failed PINs lock the app. A revoked device is refused at the next contact and **wipes its local store** when the handshake says so.
6. **Clock integrity.** The device stamps its own time, the server records server time at sync; a large skew flags the batch for review rather than rejecting it (NFR-OFF-006).
7. **Low-end constraints.** Target a 2 to 3 GB RAM Android phone, a first download under about 5 MB (spec NFR-PRF-003), a typical page under 200 KB, offline operations under 1 second (NFR-PRF-002).

## 5. Technology options (the client) **[open: WEB and Femi]**

| Option | Strengths | Weaknesses |
|---|---|---|
| **A. Installable PWA** (WEB's React, IndexedDB, service worker) | one codebase, no store, updates instantly | storage can be evicted by the browser (worse on iOS), limited background sync, weaker encryption story; Femi said "an App" |
| **B. The same React app in a native shell** (Capacitor or a trusted web activity) with a SQLite store | **one UI codebase under WEB**, a real installed app, native storage and encryption, background work, store or sideloaded APK | a second build target, a plugin set to maintain |
| **C. Native Android** (Kotlin, Room with encryption, WorkManager) | the most robust offline behaviour, best on low-end phones | **a second UI codebase** and WEB owns all UI (the standing rule); iOS excluded |
| **D. React Native or Flutter** | cross-platform | a new stack and team skill, a third UI codebase |

**Recommendation [proposal]: B**, because it keeps one UI owner and codebase, gives Femi "an App on a mobile device", and avoids the browser's storage eviction and weak encryption; with **A as a stage-0 prototype** to prove the sync semantics cheaply before the shell is built. This is WEB's and Femi's call; the server contract above is the same for A, B, C and D.

## 6. Distribution and updates **[open]**

Play Store versus a **sideloaded APK** (data cost and no-store schools matter in this market) versus PWA install; a **minimum app version** enforced in the handshake so an old client cannot push an obsolete contract; a rollout order consumer-first (server accepts old and new); the separate-origin question from `EduSys_Separate_App_SPUTO.md` (origin isolation of children's data) applies to option A and is moot for a native shell, which has its own storage.

## 7. Open questions

| # | Question | For | Proposal |
|---|---|---|---|
| O1 | Technology | WEB and Femi | **Decided 2026-10-13 (Femi: "I agree"): B, the same React app in a native shell with local encrypted storage, built under WEB**; A is only an optional stage-0 prototype |
| O2 | Distribution: Play Store, APK or both | CM, Femi | both; the handshake enforces a minimum version |
| O3 | **Shared classroom phones**: allow several teachers on one device | Femi, ER | not in v1: one device, one teacher; revisit with the S6 model |
| O4 | iOS support in v1 | Femi | no (Android first, the Nigerian arrowhead), revisit |
| O5 | Late-sync deadline for offline marks and attendance (D4) | Femi via CM | a per-school setting with a conservative default, surfaced in the handshake |
| O6 | Which languages | WEB, Femi | English first, French packs later |
| O7 | The SMS or WhatsApp fallback for critical alerts | N1 | later |

## 8. Build order (this is F12) and tests

1. **Server first, small:** S3 (JSON push), S4 (handshake), S5 (limits), then S1 and S2 (marks and bundle).
2. **Client stage 0 (prototype):** attendance register offline on a PWA store against the existing routes, to prove the outbox, the retries and the conflict UI.
3. **Client stage 1:** the native shell (if O1 is B) with the encrypted store, PIN, handshake and wipe; attendance first, then **mark entry**.
4. **Stage 2:** the roster and timetable lookups, the sync status screen, the minimum-version rollout.

**Tests that gate each stage:** a device-simulated offline run (not only service unit tests); **three days offline then sync with no loss** (spec acceptance 3); a **power cut mid-save**; **two devices marking the same register** (a conflict, never an overwrite); **a revoked device** (refused and wiped); **a retried batch** (applied once); **clock skew**; token expiry across a long offline period; a throttled 3G run; a low-end phone run.

## 9. What this does not decide

The UI design (WEB's), the brand and icon (decided: EduSys wordmark), the hosting path versus subdomain (that SPUTO), and anything beyond the v1 scope in section 1.
