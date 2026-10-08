# RBAC: Fixed Asset Register (FA) statement

**Owner:** Fixed Asset Register (FA) session. **Status:** DRAFT v0.1, 2026-10-08. **Docs-only; no code changes** (RBAC freeze). **Answers:** CM's request of 2026-10-08, relayed from Femi ("review, analyse and collaborate/coordinate on the RBAC as it concerns each peer"), against `docs/RBAC_SPUTO.md` v0.2.

**Verified against:** GL `origin/master` `b4723da`, WEB `origin/master` `b97ced6`, FiSH `origin/master` `c460b17`. Items marked **[verified]** were read from that source or grep-checked by this session. Items marked **[reading]** are this session's interpretation of the code and were **not run**. Items marked **[GL confirmed]** were sent to the GL session on 2026-10-08 and confirmed by it the same day against master `b4723da`, with file and line references (GL's confirmation also widened F-FA1; see below). Nothing in this document has been exploited or executed.

**What FA is, for this purpose.** FA has no service of its own. The aggregate, use cases and routes live in GL (`FixedAssetRoutes.kt`, `Create/RecordDepreciation/AssessImpairment/Dispose/ComputeRegister` use cases); the screen is `FixedAssetRegister.tsx`, a sub-tab of WEB's GL page. So every code change below belongs to the GL session (and WEB for the screen). FA supplies the analysis and the requirements.

---

## 1. Current authorization rules of the fixed-asset routes

All six routes use GL's shared `authorizeTenant` (EA `GET /me` per request, Membership in the Tenant, `accessLevelAt(companyId)` at least the floor, EA unreachable gives 503). **[verified]**

| Route | What it does | Level required | Company the check uses | Module grant checked | Actor recorded |
|---|---|---|---|---|---|
| `GET /companies/{companyId}/fixed-assets` | List register entries | READ | path `companyId` | none | n/a |
| `GET /companies/{companyId}/reports/fixed-asset-register` | Register plus totals (held assets only) | READ | path `companyId` | none | n/a |
| `POST /fixed-assets` | Creates the register entry **and posts the acquisition**: Dr Fixed Asset, Cr Cash (investing), or Cr AP control (tagged with a supplier reference), or Cr Suspense for already-owned assets | WRITE | body `companyId` | none | none |
| `POST /fixed-assets/{id}/record-depreciation` | One year's straight-line charge, capped at remaining book value | WRITE | `period.companyId` (from body `periodId`) | none | none |
| `POST /fixed-assets/{id}/assess-impairment` | Moves accumulated impairment to a target set by a caller-supplied recoverable amount; posts the difference (loss or reversal) | WRITE | `period.companyId` | none | none |
| `POST /fixed-assets/{id}/dispose` | Removes the asset; posts cost, accumulated depreciation, impairment and caller-supplied proceeds through the "Sale of Fixed Asset" clearing account; gain or loss falls out of the ledger | WRITE | `period.companyId` | none | none |

Facts that sit across all six **[verified]**:

- **No FA route needs APPROVE or ADMIN.** The module argument to `authorizeTenant` is `null` on every FA route, so FA is implicitly "the GL module" and no grant is checked. (Only the TAX routes pass a module on GL master.)
- **Service tokens bypass the check entirely** (`AuthenticatedCaller.isServiceAccount`). No sibling service has a reason to call these routes today, but any POP/SOP/IM/HR token can.
- **No separation of duties.** One WRITE user can register an asset, depreciate it, impair it and dispose of it. **Disposal has no approval gate**, matching the survey.
- **Nobody is recorded.** The routes discard the `AuthorizedCaller`; `FixedAsset` has no `createdBy`/`disposedBy`; the journal entries carry a description such as "Disposal - name (id)" and a source (`MANUAL`, or `IMPORT` from the opening-figures importer), not a user. GL has an `AuditLogEntry` (domain entity, repository, `V27` table) with an `actorEmail` field, but a grep for `AuditLogRepository` outside `domain/audit` and the persistence layer finds **no caller**: the audit log has no writers on master.
- **Disposal is one-way.** The only assignment of `isDisposed = true` is in `dispose()`; nothing sets it back (the other hit is `reconstitute`). A wrongful disposal cannot be undone through the aggregate.
- **Optional idempotency.** The four mutating routes honour an `Idempotency-Key` header when one is sent. This is replay protection, not an authorization control.
- **Business-rule guards that do exist** (not RBAC, but they limit damage): every Account must belong to the asset's own Company (the 2026-09-23 fix, with a use-case test per route); the Period must be open; a disposed asset cannot be depreciated, impaired or disposed again; disposal needs an impairment account when impairment exists; Land is not depreciated.
- **Tests:** `FixedAssetRoutesTest` runs as an ACCOUNTANT only. There is **no 403 or READ-level negative test** for any FA route (zero "Forbidden"/"403" in the file).
- **WEB:** `FixedAssetRegister.tsx` on WEB master has no capability gating at all (no `isOwnerAdmin`, `accessLevel` or `grantedModules` reference); the add form and the three per-row action forms show to anyone who can open the tab. **[verified; FiSH+ER WEB to confirm it is current]**

### Findings specific to FA

- **F-FA1 (HIGH, [GL confirmed]; exploit never run): the Period's Company is never compared with the asset's Company.** The three mutation routes authorize at `period.companyId` taken from the request body (`FixedAssetRoutes.kt` 217-219, 262-264, 308-310), while the asset is looked up by the path id. The use cases check Accounts against `fixedAsset.companyId` but contain no `period.companyId == fixedAsset.companyId` comparison. So WRITE at Company A, supplying a Period of A and an asset id plus account ids belonging to Company B, appears to authorize a posting against B's asset. UUIDs make it hard to exploit, but it breaks P6 ("a decision is made at the record's own Company"). `POST /fixed-assets` has the same shape: it authorizes at body `companyId` (`FixedAssetRoutes.kt` 130-132), while `PostJournalEntryUseCase` checks Accounts against `period.companyId` (line 97), with no `companyId == period.companyId` check.
  - **Wider than FA, per the GL session** (reported by GL, not independently re-checked by this session): the same pattern is on **every body-`periodId` posting route**. GL found exactly one `period.companyId` comparison in the whole application layer (`ComputeTaxUseCase.kt:74`). The thin integration routes (record-sale, record-collection, record-sales-return, record-obligation, record-payment, record-receipt, record-issue, record-pay-run, the leave accruals) authorize at the body `companyId`, then take the body `periodId` and check accounts against that Period's Company only. A caller authorized for Company A who supplies Company B's Period and B's account ids posts into B's books, and `X-Tenant-Id` does not stop it because it is compared with the Tenant of the body's `companyId`, not the Period's. Service credentials hit the same path. GL characterizes it as a cross-Tenant write-integrity gap, hard to exploit (needs B's Period and account UUIDs).
- **F-FA2 (MEDIUM, [GL confirmed]): P9/R10 fail for FA.** No actor on any FA action, and the audit log exists but nothing writes to it (`authorizeTenantForWrite(...) ?: return@post` discards the caller; `FixedAsset` has no `createdBy`/`disposedBy`).
- **F-FA3 (MEDIUM, [GL confirmed]): service tokens can call FA routes** (blanket bypass at `Auth.kt:358`, no per-credential route restriction; SPUTO F6/R7).

---

## 2. Where approval should sit (P3 / R2)

These are recommendations for CM and Femi, not decisions. Nothing here changes until the freeze lifts.

| Action | Recommendation | Why |
|---|---|---|
| **Disposal** | **Approval required, any amount.** Two steps: a WRITE user *requests* (records the requester, flags the asset "disposal pending", posts nothing); an APPROVE holder *approves* (approver from the token, never a body field; approver is not the requester unless the Owner, flagged per D6). Posting happens at approval. | Permanent removal from the books (no un-dispose), caller-supplied proceeds, touches cash, and the gain or loss is derived from numbers the requester typed. This is the clearest P3 case in FA. |
| **Impairment and its reversal** | **Approval required**, same mechanism as disposal. | Judgment-based: the charge comes from a caller-supplied recoverable amount, and the reversal path writes profit back. |
| **Revaluation** | **Does not exist in code** (no revaluation in the FA domain or application on master; land revaluation is designed policy only). When built it should be **approval-gated from its first release**, never a WRITE-only path. | Hits an equity reserve and OCI. Cheaper to build gated than to retrofit. |
| **Acquisition (create, which posts)** | **Open (D-FA1).** Option A: leave at WRITE, since a real asset is evidenced by an invoice and Phase 2's PO-driven path inherits POP's PO approval. Option B: approval above a Company limit set by an ADMIN (R3). This session leans to B **only if** CM adopts one platform limit for manual postings (T12's "manual journals above a limit"); FA should reuse that limit, not invent its own. | Posting is immediate on the caller's word. The "already owned" path credits Suspense, which is lower risk to profit but still lands any amount on the balance sheet. |
| **Depreciation** | **No approval gate.** WRITE is enough, with the actor recorded. | Formulaic: straight-line, capped at remaining book value, no caller-supplied amount (only date and accounts). Gating it would add noise without reducing risk (see objection O1). |
| **Register and report reads** | READ at the Company, plus the GL module grant once GL routes are module-gated (G5). | No change in substance. |
| **Policy/threshold configuration** | ADMIN-only and audited (R3). FA has no such policy today; categories are a fixed enum and useful life is an input per asset. | If D-FA1 option B is chosen, the limit is FA's first real use of the otherwise unused ADMIN gate. |

Notes:

- **One-person Company (D4/D6).** The Owner holds the approver role from registration, so request-and-approve by the same person is allowed and flagged in the audit record. WEB may offer the Owner a single "dispose and approve" action; that is a UI decision for WEB and CM, not a rule change.
- **Open sub-question O-D1 (for Femi/CM): are proceeds and date fixed at request, or can the approver amend them?** This session recommends fixed at request (reject and re-request to change), so the approver approves exactly what was asked.
- **Phase 2 interplay** (PO-driven acquisition, Asset-Under-Construction, disposal via SOP, all parked): PO-driven creation would arrive by service call and inherit approval upstream (POP's T9). That call should be a scoped endpoint under R7 from day one, not another blanket service bypass.

---

## 3. Gaps against T12, with rough estimates

Estimates are this session's rough guesses in working days, **not reviewed by the GL session**, and exclude review and deploy (CM's). They assume T5a (capability set on `/me`) and T6 (Owner's explicit assignments) land first where marked.

| # | Gap | Owner | Depends on | Rough size | Freeze |
|---|---|---|---|---|---|
| G1 | **One shared check across ALL body-`periodId` posting routes** (the period must belong to the authorized Company, otherwise treated as period not found), covering FA's four routes among them; plus tests. FA's share is the three mutation use cases and create. | GL | none | about 0.5 day plus tests (GL's estimate, for the whole set) | Adds a deny, changes no role, needs no decision; **GL supports and is raising it with CM as a safe-now task beside T1 to T4** |
| G2 | Record the actor on the four mutating actions and write `AuditLogEntry` (its first writers); backfill is impossible for past actions, accept and document | GL | minimal shape from T17/EA, or a GL-local interim using the existing entity | 1 to 1.5 days plus a migration | Policy-neutral, but CM to confirm |
| G3 | FA's use of **GL's single shared pending-action mechanism** (GL's position: one mechanism, GL's, not one per feature). GL's proposed shape, not yet designed or started: a pending-action record (company, action type, payload, created by, status, decided by, self-approval flag) that executes the existing use case on approval, serving fixed-asset disposal, manual journals above a limit, and opening balances or imports. **The mechanism's content is T12's, in GL's own statement; this document does not specify a separate FA design.** FA contributes only the FA-specific requirements in section 2. | GL | T17 (an actor on entries), T5a (an APPROVE capability that means approve), R2 rules | FA-specific part (disposal and impairment as action types, request and approve routes over the shared record): roughly 1 to 2 days on top of the shared mechanism; the mechanism itself is GL's to estimate | Frozen |
| G4 | WEB: capability-gated buttons, request vs approve forms, a "pending approval" list, optional Owner shortcut | FiSH+ER WEB | G3's contract, R11 | 2 to 3 days | Frozen |
| G5 | Module grant on FA routes. GL routes generally check no module (only TAX does). Decide whether FA sits under `ManagedModule.GL`. If so, T6 must first give every Owner an explicit GL-module assignment or Owners lose access | GL, EA, CM | T6 | small code, decision-heavy | Frozen |
| G6 | Service-token reach to FA routes (F-FA3) | GL, EA, CM | R7/T15 | 0 now | Frozen |
| G7 | Role-matrix tests for FA routes: READ gets 403 on writes, no-membership gets 403, wrong-Company gets 403 | GL | none | 0.5 day | Tests only; **asking CM to carve out** |
| G8 | Revaluation, if ever built, ships gated (see section 2) | GL | G3 | n/a now | n/a |

Order this session suggests: G1 and G7 now (if CM agrees), then G2, then G3 and G4 together once T5a is live.

---

## 4. Objections and clarifications

- **O1: P3 should not be read to cover depreciation.** P3 says any record that moves money or stock value needs a different approver. Depreciation moves book value but is formulaic with no caller-supplied amount; an approval step adds friction without catching anything. Request: CM scopes P3 to postings where the creator supplies an amount or judgment (disposal, impairment, revaluation, acquisition above a limit, manual journals).
- **O2: carve G1 and G7 out of the freeze.** Neither changes who can do what in the intended model; G1 closes a cross-Company (and per GL, cross-Tenant) write-integrity hole across all body-`periodId` routes, and G7 only adds tests. Same character as T1 to T4. The GL session supports this and is raising G1 with CM. This is CM's call.
- **O3: T12 names "FA disposals" only.** Impairment needs the same gate for the same reasons (section 2). Suggest T12 read "FA disposals, impairments and reversals, revaluations (when built), and manual journals above a limit".
- **O4: disposals should not be threshold-gated.** Unlike a manual journal, a disposal of any size is a permanent register change. Recommend approval at any amount.
- **Adjacent, out of scope here.** The opening-figures importer (`ImportFixedAssetsUseCase`) posts through `CreateFixedAssetUseCase` with `JournalSource.IMPORT` and carries a `createdByEmail` of its own. Its authorization is its route's, not FA's; whoever owns that route should cover it in their statement.

---

## 5. Needs

- **GL:** F-FA1 to F-FA3 confirmed 2026-10-08 (F-FA1 widened to every body-`periodId` route). GL owns all backend changes (G1 to G3, G7). GL has said the approval mechanism is one shared GL mechanism (T12), so FA waits on GL's statement for its design. Still open: where audit entries go (depends on T17).
- **EA:** T5a, with the approve capability reported per Company on `/me` so GL can check it; T6, with the Owner's explicit assignments including approve at every Company (and the GL module if G5 goes ahead); T17, the minimal audit shape.
- **FiSH+ER WEB:** R11 gating on `FixedAssetRegister.tsx`; request/approve forms and a pending list once G3 has a contract; confirm the current state of that component.
- **CM:** carve-out of G1 (GL and FA both support it, GL is raising it too) and G7; ordering of G2 to G4 behind T5a; take D-FA1 and O-D1 to Femi.
- **Femi, via CM:** D-FA1 (acquisition at WRITE, or approval above a limit) and O-D1 (proceeds fixed at request, or amendable by the approver).

---

## 6. Row for the SPUTO status table

| Service | Current-rules statement | Gaps vs this SPUTO | Plan / branch | Reviewed by CM |
|---|---|---|---|---|
| FA (code in GL, screen in WEB) | this document | F-FA1 (Period/asset Company, confirmed by GL and wider than FA), F-FA2 (no actor, audit log unwritten), F-FA3 (service-token reach), disposal and impairment ungated, no negative tests | G1 (shared check, all routes) and G7 now if carved out; G2; then G3 and G4 behind T5a and GL's shared mechanism | pending |

---

## 7. Verification log

Read directly from GL `origin/master` `b4723da`: `FixedAssetRoutes.kt` (the `authorize*` call on each route), `Auth.kt` (`authorizeTenant`, the service-account bypass), `ManagedModule` (`GL, HR, SOP, POP, IM, TAX, EDUCATION_RUNTIME`; no fixed-asset module), the Dispose/RecordDepreciation/AssessImpairment/Create use cases (Company comparisons), `fixed_asset.kt` (the only `isDisposed = true`), `FixedAssetRoutesTest.kt` (no forbidden cases), the audit domain and repository (no callers by `AuditLogRepository` grep). Read from WEB `origin/master` `b97ced6`: `FixedAssetRegister.tsx` (no gating references). Read from FiSH `origin/master` `c460b17`: `docs/RBAC_SPUTO.md` v0.2.

Confirmed by the GL session on 2026-10-08 (re-read against `b4723da`, with file and line references): F-FA1, F-FA2, F-FA3. The claim that F-FA1's pattern is on every body-`periodId` posting route, and that `ComputeTaxUseCase.kt:74` is the only `period.companyId` comparison in the application layer, is GL's finding and was not independently re-checked by this session.

Not verified: the F-FA1 exploit path (never run, by either session), whether any JournalEntry-level user capture exists beyond the grep for `createdBy`/`postedBy`/`actorEmail`/`performedBy` (none found on `JournalEntry` or `FixedAsset`), and live task-definition state (not needed for these findings).
