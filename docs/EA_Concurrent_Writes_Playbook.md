# EA concurrent writes: lost updates and un-revokes (Playbook)

**Status:** 2026-10-11, planning only (SPUTO: Scope, Plan/SRS, Use cases, Tasks, Order). Nothing in this playbook is built; the hardening bundle (PR 46: per-Tenant lock on registration and onboarding) is separate and continues. **A decision is asked of Femi in section 7.** Written by the EA session at CM's request. Facts are from EA master and its tests, read on 2026-10-10 and 2026-10-11.

## 1. Scope (S)

**In:** every place EA loads an aggregate, changes it in memory and saves it back: a Tenant, a Membership, a message's read marks, a new User. **Out:** other services' databases; performance tuning; cross-Tenant ordering (a Tenant is the unit of consistency).

## 2. The problem in plain words, and the evidence

EA saves by **replacing the whole record**: it reads a Membership, changes one thing, and writes the *entire* Membership back (its status, every assignment, every module). If two requests do this to the same record at the same moment, the one that saves last overwrites the other's change, even a change it never looked at. Nobody gets an error; one change just disappears.

**The persistence pattern, per repository (read from the code):**

| Repository | What a save does | What a concurrent save can undo |
|---|---|---|
| Tenant | updates the row, then **deletes and re-inserts** `tenant_companies` and `tenant_admin_memberships` from the loaded copy | a Company link or admin membership added since the copy was loaded |
| Membership | updates the row **including its status**, then **deletes and re-inserts** its assignments and modules | a revoke, an assignment change, a module change |
| Message | **deletes and re-inserts** `message_seen_by` | another reader's "seen" mark |
| Company links, company name and profile | single-row upserts or column updates | nothing (safe) |
| User | find-then-insert on the unique email | a double submit gets a 500 |

**The security case, the "un-revoke".** Because a save rewrites the Membership's *status* too: (1) a request loads a staff Membership while it is ACTIVE (say an HR delegate changes the member's modules); (2) the Owner revokes that member and the revoke commits; (3) the first request saves its stale copy: **the Membership is ACTIVE again**, with its old assignments. A removed person regains access without anyone acting. The window is small, but this is an access-control reversal, so it ranks first. A test with a database-like repository (hands out copies, parks one save mid-flight) reproduces it: without a lock the final status is ACTIVE.

**Ranked paths:**

| # | Path | What is lost | Severity |
|---|---|---|---|
| 1 | Revoke against update-modules, accept, decline or re-invite | the revoke (member regains access) | **High** |
| 2 | Two assignment or module changes to one member (Owner at Company A, delegate at Company B) | one of the two changes | Medium |
| 3 | Record admin phone number against a Company registration | the new Company link (the Company vanishes from `/me`) | Medium |
| 4 | Two invites or registrations for one new email; double accept | a 500 on the loser | Low |
| 5 | The deadline sweep saving a Tenant it loaded earlier | a link added meanwhile (only Tenants whose deadline expired) | Low |
| 6 | Two people marking one message seen | one seen mark (cosmetic) | Cosmetic |

**Already fixed in the hardening bundle (PR 46):** Company registration and Tenant onboarding now run one at a time per Tenant (a Postgres advisory lock), and a double submit of `POST /tenants` returns the Tenant already created.

## 3. Requirements (P, the plan)

- **R1** A revoke is final: no concurrent or later write may restore ACTIVE status or removed assignments. Only an explicit re-invite and accept can.
- **R2** Two concurrent changes to one Tenant's staff either both take effect or the second is told to retry. A change is never silently lost.
- **R3** A change that cannot run is answered `409 tenant_busy` with plain wording, and **nothing of it ran** (safe to retry).
- **R4** Reads are never blocked.
- **R5** No deadlocks; every wait is bounded (20 s) and holders are capped (4) so a burst cannot exhaust the database pool.
- **R6** Naturally idempotent writes stay idempotent: a user's email, a message's seen mark.
- **R7** Every wait that ends in "busy" is logged with the Tenant id.
- **Not required:** ordering across Tenants; distributed consensus; a new datastore.

## 4. The three fix patterns, and their dependency order

| | What it is | Fixes | Cost and risk | Rollback |
|---|---|---|---|---|
| **A. Per-Tenant write lock** | every Tenant or Membership write runs under the lock the bundle already introduced (Postgres advisory lock keyed by Tenant id), with the aggregate loaded **inside** it | paths 1 to 3 and 5 completely | about 3 days; code only, no migration; writes to one Tenant queue (rare admin actions) | redeploy the previous image; no data change |
| **B. Per-row writes** | replace delete-and-reinsert with insert-if-missing and delete-what-was-removed; revoke becomes a status-only `UPDATE`; seen-by and user create become `ON CONFLICT DO NOTHING` | additive changes can no longer clobber each other even without a lock; closes 4 and 6 | about 2 days; touches two repositories; needs careful integration tests | redeploy; no schema change |
| **C. Version column** | `version` on tenants and memberships; `UPDATE ... WHERE version = ?`; conflict means 409 or retry | any lost update, without holding a lock | about 3 days, a migration, every use case handles the conflict | ignore the column |

**Order and why.** **A first**: it is additive (the use cases already exist; they gain a lock), it closes the high-severity path quickly, reuses reviewed code (`KeyedLock`, `BoundedKeyedLock`), and needs no migration. **B second**: once A is in, B's persistence change can land safely and is verified by tests that run with and without the lock; it makes the system correct even where a lock is forgotten. **C only if** load grows or writes begin to hold long calls under a lock (an upstream call inside a registration holds the Tenant for up to the 15 s timeout, which is acceptable today); it builds on B. A then B is the recommended scope; C is a gate, not a plan.

## 5. Use cases and expected outcomes (U)

| ID | Situation | Expected |
|---|---|---|
| UC-C1 | An update of a member's modules is mid-flight; the Owner revokes the member | the member ends **revoked**; the update completes or is told to retry; never ACTIVE |
| UC-C1b | A revoke is mid-flight; an update of the same member arrives | the member ends revoked; the update loads the revoked state and does not change the status |
| UC-C2 | Owner changes a member's modules at Company A while a delegate changes them at Company B | both changes survive (A), or the second gets `tenant_busy` and retries (never lost) |
| UC-C3 | The Owner saves the admin phone while a Company registration runs | the new Company link survives |
| UC-C4 | Accept clicked twice | one acceptance; the second answers "already responded", not a 500 |
| UC-C5 | Two invites for one new email at once | one User, one invite each; no 500 |
| UC-C6 | Two people mark a message seen at once | both marks exist |
| UC-C7 | The deadline sweep suspends a Tenant while a registration adds a Company | the Company link survives |

## 6. Tasks (T), each tests-first, one commit each, HIGH review

| Task | Content | Tests first | Size |
|---|---|---|---|
| **T1** | Revoke and update-modules under the Tenant lock, loading the Membership inside it; `409 tenant_busy`; update on a revoked Membership keeps it revoked | **the concurrent revoke-versus-update test on real threads, both orders, final status REVOKED**; a negative control with no lock showing the bug (final ACTIVE); a Postgres integration test of 30 rounds on the real repository and advisory lock | 1 d |
| T2 | Record admin phone under the lock | a concurrent registration plus phone save keeps the link (UC-C3) | 0.25 d |
| T3 | Accept, decline, invite under the lock | double accept; invite versus revoke | 0.5 d |
| T4 | The sweep takes the lock per Tenant and reloads inside it | sweep versus registration (UC-C7) | 0.25 d |
| T5 | `ON CONFLICT` for user creation (invite and register) | two invites for one new email (UC-C5) | 0.25 d |
| T6 | `ON CONFLICT DO NOTHING` for seen-by | two readers (UC-C6) | 0.25 d |
| T7 | Map `tenant_busy` on every affected route; log busy waits with the Tenant id; update WEB's note | route tests; log test | 0.25 d |
| **T8 (B)** | per-row upserts and removes for company links, assignments, modules; revoke as a status-only update | the same concurrent tests **with the lock disabled** must still pass; plus integration tests | 2 d |
| T9 (C) | version column | decision gate, only if triggered | 3 d |

## 7. Order, rollout, rollback, and the decision

**Order:** T1 (path 1, the security case), then T2 to T4 in that order, T5 and T6 (small, independent), T7 alongside each, then B (T8) as a separate branch after A is live. Each task is its own branch or commit, reviewed HIGH by CM, released on a green Postgres build (CM's CI is the only place the Postgres tests run for now).
**Rollout:** code only for A, no migration; EA deploys rolling, so during the few minutes both old and new tasks run, an old task can still write without the lock, which is the same exposure as today and not worse. T1 goes first and alone so its effect is visible.
**Rollback:** redeploy the previous image; no data or schema changes in A or B.
**Risks of A:** a Company registration that calls Education Runtime holds its Tenant's lock for up to the 15 s timeout, during which staff changes for that Tenant answer `tenant_busy` after waiting; lock holders keep a database connection each (capped at 4).
**What other sessions must know:** WEB: a new `409 tenant_busy` ("Another change to this business's staff is still running; try again") on revoke, module change, invite, accept and decline: show a plain retry message. Every other service: nothing; `/me` and the DTOs do not change.
**Decisions asked of Femi:** (1) approve A (T1 to T7, about 3 days) now, B (T8, about 2 days) after, C not planned. (2) A small behaviour change inside T1: should changing the modules of an **already revoked** member be refused (recommended: yes, `409`) rather than allowed but ignored?

*Evidence read 2026-10-10 to 11: the persistence classes (`exposed_tenant_repository`, `exposed_membership_repository`, `exposed_message_repository`), the nine use cases that save, and the lock tests in PR 46. The un-revoke is reproduced in a unit test with a copying repository; it has not been observed in production.*
