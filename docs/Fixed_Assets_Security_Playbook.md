# Fixed Asset Register: security Playbook (SPUTO)

**Status: DRAFT v0.1, 2026-10-13. Planning only. Nothing is built; no code until Femi approves (RBAC freeze stands).** Written by the Fixed Asset Register (FA) session at Femi's request ("Prepare a playbook that will secure FA"; "A full SPUTO should be done to cover FA"; "Very important to close this gap").

**Peer confirmations, 2026-10-13:** GL confirmed the three readings below against master `743e418` (depreciation has no per-year record; manual journals to 1200 are accepted; the acquisition date is not checked against the Period's dates); EA and POP replied with the platform facts folded into section 6 and section 9. Nothing built.

**Verified against:** GL `origin/master` `ccddf1b`, FiSH `origin/master` `0f50918`. **[verified]** = read from that source. **[reading]** = this session's interpretation of code, **not run**. Nothing here has been exploited or executed.

**What FA is.** No service of its own: aggregate, use cases and routes live in GL; the screen is `FixedAssetRegister.tsx` in WEB's GL page. Every code change below is GL's (and WEB's for screens). FA supplies the analysis and the requirements.

**Builds on, does not repeat:** `docs/RBAC_FA_Statement.md` (route rules, F-FA1 to F-FA3, G1 to G8), `docs/GL_Fixed_Asset_Register_GL_Link_SPUTO.md` (register tied to the ledger, P1 to P4), `docs/RBAC_SPUTO.md` v0.2 (P1 to P9, R2, T5a, T12, T17), `docs/Playbook_Definition.md` (the six parts). Task ids here are `FS-n`; each says which of those it extends.

## 0. Decisions already made (Femi)

| Date | Decision | Source |
|---|---|---|
| 2026-10-13 | **Fixed at request, for disposals AND acquisitions.** The figures and date typed by the requester are what gets posted. The approver can only approve or reject, never change a figure. A change means reject and raise a new request. ("That is opening the system to fraud if it is allowed to change." Corrected after CM trimmed it to disposals only: "NO... Disposals and Acquisitions".) | Decisions_Log |
| 2026-10-13 | **The acquisition gap must be closed.** Someone recording an asset that does not exist is a real danger. ("Very important to close this gap.") | told directly |
| 2026-10-13 | **Both directions of error matter.** "Inflated FA means false profits and a threat of going concern status." Understating hurts too (hidden value, wrong tax, a lender misled the other way). | told directly |
| 2026-10-13 | **D-FA-A resolved: every asset purchase, at any amount, requires approval from the Owner Admin.** ("It will require approval from the Owner Admin", clarifying his earlier "yes, except it is Owner Admin".) | Decisions_Log |
| 2026-10-13 | **D-FA-F and D-FA-G settled by Femi's standing rule "The owner is the final authority"** (relayed by CM): the Owner Admin approves acquisitions, disposals and impairments, and when the Owner Admin is the requester or buyer they remain the approver, with the self-approval recorded and flagged in the attention list and the audit (option (a)). CM says it is logged in Decisions_Log; that entry was not yet on master when this was written | CM, from Femi |
| 2026-10-23 | **The purpose of internal control in FiSH is to protect the owner from being defrauded**: "put systems in place, as far as we can possibly do, to prevent the owner of a business from being defrauded by integrating good quality internal control systems into FiSH". Read together with "it is not up to us to police the Owner": the owner's own entries are recorded and flagged, not blocked; the controls guard the owner against staff, suppliers, buyers and mistakes. Section 6.6 proposes the extensions this asks for | Decisions_Log |

Still **not** decided, and asked in section 7: the reference rule (D-FA-C); blocking manual journals (D-FA-D); policy ranges (D-FA-E). Impairments go through the Owner Admin's approval (D-FA-B first half: confirmed yes, 2026-10-13, from "the owner is the final authority"); that the approver also cannot change the impairment figures is FA's recommendation and the default design, **Femi to confirm** (his "fixed at request" covered disposals and acquisitions).

## 1. Operator sheet (what the system does TODAY)

*For Omniview's Playbooks tab once approved. Written from GL `ccddf1b`.*

**Q: Who can record, depreciate, impair or dispose of a fixed asset?** Anyone with WRITE at the Company. There is no second person, no limit and no approval step. **[verified]** (`authorizeTenantForWrite`; no module grant is checked.)

**Q: Does recording an asset move the books?** Yes, immediately. `POST /fixed-assets` posts the acquisition first, then saves the asset: Dr Fixed Assets; Cr Cash (investing cash flow), or Cr Accounts Payable (tagged with a free-text supplier reference), or Cr Suspense 3910 for "already owned". **[verified]**

**Q: Is there evidence behind an asset?** No. The supplier reference is typed text and is not checked against any invoice or purchase order. A cash purchase carries no reference at all. `identifier` (serial or registration) is optional. **[verified]**

**Q: Can I edit or delete an asset?** No. There is no edit, delete or void route; useful life, cost and date are fixed at creation. A mistaken asset can only be disposed of. **[verified]**

**Q: Can I post to account 1200 with a manual journal?** The journal route accepts any account in the Company; only the cash-book path refuses module-owned accounts (`ModuleOwnedAccounts`). So a manual journal to 1200 is not blocked, and neither are 1210, 1100, 2000, 1300 or 2150. **[confirmed by GL against master 743e418, read in code; not run]**

**Q: How must an asset be sold or written off?** Through the disposal route (`POST /fixed-assets/{id}/dispose`), never by a manual journal. The route posts the difference between the proceeds and the asset's carrying amount to a loss account (expense) or a gain account (income), or to Suspense if none is named, and it refuses a revenue account as the loss account (since 18 Oct 2026, GL commit `0d29e8f`). A hand-typed disposal journal skips those checks and does not mark the asset disposed in the register. What the route does **not** yet check: the cash, fixed-asset and accumulated-depreciation accounts are checked only for belonging to the Company, not for type, and a gain can be sent to a revenue account such as Sales (finding F22-20; FR-FA26, FS-24). **[verified in code and tests, GL master 0d97943]**

**Q: Can I run depreciation twice?** The route is idempotent per request key, but nothing remembers which year or period an asset was depreciated for. Two requests with different keys post two full annual charges, until net book value reaches zero; only the same key and body replays the first answer. **[verified; confirmed by GL]**

**Q: Who did it?** Not recorded on any FA action. The audit log table exists; nothing writes to it. **[verified]**

**Q: Can a service token call these routes?** Yes (blanket service-account bypass). **[verified]**

**Error glossary (HTTP, GL):** `period_not_open` 409 (the period is closed or not open for posting); `period_not_found` 404; `fixed_asset_not_found` 404; `already_disposed` 409; `no_change_needed` 409 (depreciation or impairment would change nothing: land, fully depreciated, disposed, or no impairment movement); `no_fixed_assets` 409 (register report of a Company with none); `*_account_not_found` 404 (the account is not in this Company); `invalid_fixed_asset` 400; `invalid_posting` 400; `accumulated_impairment_account_required` 400; idempotency conflicts as GL's shared handler reports them.

**Before escalating, collect:** Company id, asset id, the request key, the period id, the account ids used, and the time.

**NOT BUILT / not deployed:** any approval or second-person step; evidence on acquisition; actor on any action; audit entries; per-period depreciation guard; manual-journal block on 1200; register-to-ledger tie (GL link SPUTO, designed, not built); revaluation; PO-driven acquisition (POP, Phase 2); void or correction of an asset.

## 2. Scope (S)

**In:** securing the whole life of a fixed asset against false recording in either direction: acquisition, depreciation, impairment, disposal, and every other way of moving account 1200, its accumulated-depreciation and accumulated-impairment accounts; who may do each; evidence; approval; attribution; detection of what still gets through.
**Out:** revaluation (not built; if built it ships gated, G8), the cash-book and VAT work, EA's role model itself (FA consumes T5a/T6/T12/T17, does not design them), tax computation, the opening-figures importer's own route security (covered here only where it creates assets).

## 3. Threat model (what we are securing against)

Read every row as a way the **owner** is harmed: a member of staff books a ghost asset to cover a theft, sells a real asset cheaply to a friend, or buries a missing one. Each row names the false statement it creates. **Direction** says whether it overstates (O) or understates (U) assets and profit.

| ID | Attack or error | Direction | Today | Closed by |
|---|---|---|---|---|
| A1 | **Record an asset that does not exist** (fake supplier ref, or "already owned") | O: assets and equity up; going-concern view false | open: one person, no evidence | FS-6a (evidence), FS-7 (approval) |
| A2 | **Capitalise an expense** (a repair or consumable booked as an asset) | O: profit up now | open | FS-6a, FS-7 (the approver sees the asset), FS-12 policy |
| A3 | **Split one purchase** into pieces to stay under a limit | evasion | not applicable today; matters only if a limit is chosen | closed by decision D-FA-A: approval at any amount, so there is no limit to split under |
| A4 | **Skip or reduce depreciation** (never run it; a longer life) | O | life is a fixed input at creation but nothing makes depreciation run | FS-13 detects a missing charge, FS-12 bounds the life; FS-4 does not apply (it stops a second charge, not a missing one) |
| A5 | **Depreciate twice** | U | open (section 1) | FS-4 |
| A6 | **Understate impairment** (ignore a fall in value) | O | open: caller-supplied recoverable amount, no evidence | FR-FA16 and FS-7 (impairments are in the approval step); FS-13 detects a large write-down |
| A7 | **Overstate impairment** ("cookie jar" reserve to hide profit or shift it between years) | U | open | FS-7 (impairments are in the approval step) |
| A8 | **Dispose at a false price** (understate proceeds and keep the cash; or overstate proceeds to book a false gain) | O or U | open: proceeds caller-supplied | FS-7, FS-9 |
| A9 | **Dispose of an asset that still exists** (hide it, or write off a real asset to cut the register) | U | open | FS-7 |
| A10 | **Manual journal straight to 1200** or its contra accounts, bypassing every control above | O or U | open **[reading]** | FS-10 |
| A11 | **Cross-Company write**: a period from Company A used to authorize an action on Company B's asset (F-FA1) | O or U | **closed 2026-10-08 by GL's T19 (commit 191fd9f), pinned by tests.** This Playbook's first draft listed it as open; that was FA's error (see section 10) | FS-1 (done) |
| A12 | **Backdated acquisition** into an earlier open period | O or U | the date is not checked against the Period's start and end anywhere, for any posting route **[confirmed by GL: new shared GL code, not a reuse; GL's own `docs/GL_Period_Management_Scoping.md` options L1 to L3 await Femi]** | FR-FA17, FS-8 |
| A13 | **Service token** used to call an FA mutation with no person behind it (F-FA3) | either | open | FS-11 |
| A14 | **Unattributable action**: nobody can say who did it (F-FA2) | either | open | FS-3 |
| A15 | **Register drifts from the ledger** (an asset with no posting, a posting with no asset) | either | open; cannot be detected today (GL link SPUTO) | FS-2 |
| A16 | **Bulk import used to slip in many assets at once** (`ImportFixedAssetsUseCase`) | O | same path as one-at-a-time, so same exposure | FS-7 (batch approval) |

## 4. Plan / requirements (P)

Numbered so tasks and tests can cite them. "Must" is a requirement; recommended defaults are marked.

- **FR-FA1 Evidence on acquisition.** Every acquisition carries an evidence reference: for Accounts Payable funding, a Purchase Order or supplier invoice reference that exists in POP for this Company (free text only until Phase 2 allows more); for cash funding, the cash-book entry or receipt reference; for "already owned", an ownership reference (serial, registration, title) and a note. A reference already used for another asset of the Company is refused, which also stops recording the same invoice twice. *Open (D-FA-C): how strict free text may be until POP can verify.*
- **FR-FA2 Request, then approve.** Acquisition, disposal and (if decided) impairment are two steps. Step one records a pending request and posts **nothing**. Step two, by a different person, posts exactly what was requested. A pending asset is not in the register total and not in account 1200.
- **FR-FA3 Fixed at request.** The pending request is immutable. The approver sees every figure and the date and can only approve or reject; a new figure means a new request. The approve call carries no figures: the server posts the stored payload. (Femi's decision, section 0.)
- **FR-FA4 The approver is the Owner Admin, and the Owner Admin stays the approver of their own purchases (DECIDED: D-FA-A, D-FA-F, D-FA-G).** The approver is identified from the token, never from a name typed in a body. A person other than the Owner Admin can raise a request but never approve one. When the Owner Admin is the requester or buyer there is no second person (one Owner Admin per Tenant): the Owner Admin approves their own request, and it is recorded and flagged as self-approval, listed in the Owner's "Needs your attention" box and in the audit entry, so it stays visible (RBAC_SPUTO R2/D6). **With self-approval, this design can only make a false asset visible, not stop it.**
- **FR-FA5 Approval at any amount, by the Owner Admin (DECIDED, D-FA-A, 2026-10-13).** Every asset purchase needs approval whatever its size; there is no limit, so there is nothing to split under (A3). Disposals and impairments are approved by the Owner Admin as well (D-FA-G).
- **FR-FA6 Depreciation is once per asset per year.** The asset records the last year (or period) it was depreciated; a second charge for the same year is refused with a clear message. Depreciation itself needs no approval: it has no caller-supplied amount (objection O1 in the statement). It must be visible when it is **missing** (FR-FA10).
- **FR-FA7 Judgment inputs are bounded by policy.** Useful life per category within a range, and a minimum capitalisation cost, set by an ADMIN, audited, per Company. A request outside the range is refused, or flagged for the approver's attention (*open, D-FA-E*).
- **FR-FA8 Module-owned accounts are not postable by hand.** Manual journals cannot debit or credit 1200, accumulated depreciation, or accumulated impairment; the same `ModuleOwnedAccounts` rule already used by the cash book. A legitimate correction goes through an FA action (a void or correction path must exist first, FS-5).
- **FR-FA9 The period must belong to the Company** on every body-`periodId` route (F-FA1), not only FA's. A Period that is not the authorized Company's is treated as not found (404 `period_not_found`), never "forbidden", so it never confirms that another Company's Period exists. (A Company the person has no membership in is refused earlier, by the platform's standard Tenant check, with 401 or 403; that is platform-wide behaviour and is not changed here.) **Met today by T19 (191fd9f):** every posting use case loads a caller-named Period through `findOwnedBy(periodId, companyId)`; `PeriodOwnershipGuardTest` fails the build if an application use case uses a raw `findById`; `CrossCompanyPostingIsolationRouteTest` and the isolation matrix cover the asset-versus-Period mismatch.
- **FR-FA10 Detect what slips through.** The register shows the tie to the ledger per asset (GL link SPUTO P3), and the Owner's "Needs your attention" shows: assets not yet depreciated this year, a non-zero Sale of Fixed Asset clearing balance (proceeds not matched to cash), pending requests waiting, a non-zero Suspense balance.
- **FR-FA11 Every action is attributable.** Actor, time and the request key on every request, approval, rejection and posting; written to the audit log (T17). Past actions cannot be backfilled; accepted and stated.
- **FR-FA12 Service credentials cannot raise or approve** an FA request. Module-to-module posting by design (the importer is the one expected exception, and goes through FR-FA2 as a batch).
- **FR-FA13 Capability, not rank.** Raising and approving are separate capabilities per Company (T5a). READ cannot raise; raising does not imply approving; ADMIN alone approves nothing (D1).
- **FR-FA14 Honest screen.** WEB shows request versus approve controls per capability, the pending list, and a "Pending approval" status; never a "posted" message before the posting exists.
- **FR-FA15 Bulk import is one approval.** An imported file is one pending batch: the approver sees the full list and a content fingerprint; approve posts exactly that list; any difference means a new batch. **The requester of a batch is the signed-in person who uploads it (a human token); a batch is never raised by a service credential, so FR-FA12's importer exception means only that the import code path may call the use case on that person's behalf. The approver must be a different person (the Owner excepted, flagged).**
- **FR-FA16 Impairment evidence.** Impairments are in the approval step (D-FA-B, confirmed), so the request carries a required evidence note for the recoverable amount (valuation, quotation or basis of the estimate), stored with the request and shown to the approver; an impairment with no note is refused.
- **FR-FA17 Dates inside the Period.** An acquisition date and a disposal date must lie within the Period they post to; otherwise the request is refused. This needs GL's shared Period-date check (FS-8), which GL confirmed does not exist today for any posting route.
- **FR-FA18 Fails closed.** If the approval mechanism or EA's membership check is unreachable, nothing posts and nothing is left half-done: the caller gets 503. (`authorizeTenant` already answers 503 when EA is down; FS-7 must keep that for the new routes and test it.)
- **FR-FA25 Disposals use the disposal route.** An asset is sold or written off only through the disposal route (and, once FS-7 exists, through the disposal request flow), never by a manual journal. A manual journal that touches a fixed-asset account or a revenue account is flagged to the Owner Admin (not blocked, per the owner rule); GL is scoping that flag (CM, 24 Oct). See D-FA-D.
- **FR-FA26 Disposal accounts are type-checked (shape proposed by GL, 24 Oct, accepted by FA).** On a disposal: (1) the **cash account** must be a cash or bank book (the Company's own, active), the same rule the settlement lines already use; (2) the **fixed-asset and accumulated-depreciation accounts** must be asset-type, active, not a cash book, and not another module's control account (receivables, inventory, VAT and the like), so the pair 1200/1210 and an owner's own fixed-asset sub-accounts pass; (3) the **loss account** must be an expense account (already enforced); (4) the **gain account** may be any active revenue account that is not module-owned and **is not the Sales account (4000)**, so a gain cannot go to Sales while the owner's own choice among other income accounts stays free (the gain-on-disposal account 4930 and "Other income" pass). This is looser than FA's first draft ("gain-on-disposal account only"): it guards against the mistake without policing the owner's choice, which is the platform's stated purpose for controls. Femi may ask for the strict version. A refusal is a 400 (token plus "<accountId>: <reason>", the same shape as the existing `gain_loss_account_not_allowed`, which is a 400 on this route) and nothing posts; the response to a successful disposal does not change. Finding F22-20.

**Target error codes (PROPOSED names so tests can check exact codes; GL decides the final names; the cash book's `counter_account_not_allowed` with `useInstead` is the precedent):**

| Situation | HTTP | Proposed code |
|---|---|---|
| Second depreciation for the same year | 409 | `depreciation_already_recorded` (with the year) |
| Evidence reference missing | 400 | `evidence_reference_required` |
| Evidence reference already used in this Company | 409 | `evidence_reference_already_used` |
| Approver is the requester (not the Owner) | 403 | `self_approval_not_allowed` |
| Manual journal to 1200, accumulated depreciation or accumulated impairment | 409 | `account_owned_by_module` with `useInstead` = FIXED_ASSETS |
| Acquisition or disposal date outside the Period | 409 | `date_outside_period` |
| Request already approved or rejected | 409 | `request_already_decided` |
| Service credential used on an FA mutation | 403 | `service_credential_not_allowed` |
| Disposal cash account is not a cash or bank book | 400 | `cash_account_not_allowed` |
| Disposal fixed-asset account is not an allowed asset account | 400 | `fixed_asset_account_not_allowed` |
| Disposal accumulated-depreciation account is not an allowed asset account | 400 | `accumulated_depreciation_account_not_allowed` |
| Approval mechanism or EA unreachable | 503 | `approval_unavailable` |
| Request rejected | (a status, not an error) | status REJECTED with a required reason |

## 5. Use cases (U)

| ID | Situation | Expected |
|---|---|---|
| UC-FA1 | Staff member requests a vehicle purchase GBP 18,000, supplier ref given | Pending request created; nothing in 1200; Owner and any approver see it; requester gets "waiting for approval" |
| UC-FA2 | A second person approves it | The stored figures post exactly; asset appears in the register; actor, approver and times recorded |
| UC-FA3 | Approver tries to change the cost from 18,000 to 15,000 | Not possible: there is no field. They reject with a reason; the requester raises a new request |
| UC-FA4 | Requester tries to approve their own request | Refused (403), unless they are the Owner: allowed, recorded and flagged as self-approval |
| UC-FA5 | Request cites an invoice reference already used for another asset | Refused at request: reference already recorded for this Company |
| UC-FA6 | Request cites a supplier invoice that POP does not hold (once POP can verify) | Refused, or accepted but marked "unverified" for the approver's attention, per D-FA-C |
| UC-FA7 | "Already owned" asset with no ownership reference | Refused at request |
| UC-FA8 | Someone raises 20 small requests to avoid attention | Each one is approved or rejected on its own; none posts without approval (no limit exists to split under) |
| UC-FA9 | Depreciation requested twice for the same year | Second request refused: already depreciated for that year |
| UC-FA10 | Year-end: three assets have no depreciation for the year | Owner's attention box lists them; one action runs depreciation for the Company |
| UC-FA11 | Impairment requested with recoverable amount well below book value | Pending, approver sees the amount and the evidence note; approves or rejects; nothing changes between |
| UC-FA12 | Disposal requested with proceeds 100 for an asset worth about 5,000 | Pending; approver sees gain or loss that would result; rejects or approves exactly as typed |
| UC-FA13 | After a disposal, the clearing account still holds a balance a week later | Owner's attention box: proceeds not matched to a cash receipt |
| UC-FA14 | Accountant tries a manual journal Dr 1200 | Refused: use Fixed Assets (`use_instead` = FIXED_ASSETS), same wording as the cash book |
| UC-FA15 | A period from Company A is sent with Company B's asset id | Treated as period not found; nothing posts; nothing about Company B is revealed |
| UC-FA16 | A service token calls `POST /fixed-assets` | Refused: service credentials cannot raise FA requests (the importer's batch excepted) |
| UC-FA17 | Imported file of 120 assets | One pending batch; approver sees all 120 and the fingerprint; approving posts those 120 only |
| UC-FA18 | A person with READ opens the register | Sees the register and the ledger tie; no request or approve buttons |
| UC-FA19 | A mistaken asset must be removed | Interim (FS-5 built first): a plain WRITE action that reverses the acquisition and takes the asset out of the register, recorded with the actor and a required reason, never a silent delete. Once FS-7 exists, the same action is re-gated as a void request approved like any other |
| UC-FA20 | The approval service is down or unreachable | Fails closed (503); nothing posts |
| UC-FA21 | A request gives a vehicle a 40-year life, outside the Company's range | Refused, or flagged to the approver's attention, per D-FA-E (FR-FA7) |
| UC-FA22 | An auditor asks who recorded, who approved and who posted an asset | Each step shows the actor, the time and the request key, read from the audit log (FR-FA11) |
| UC-FA23 | Someone raises a request on screen | The screen says "Waiting for approval", never "posted", until the posting exists; if posting fails after approval, the screen shows the failure, not success (FR-FA14) |
| UC-FA24 | An acquisition is dated in an earlier month than the Period it posts to | Refused, `date_outside_period` (FR-FA17) |
| UC-FA25 | A disposal is dated outside the Period it posts to | Refused, `date_outside_period` (FR-FA17) |
| UC-FA29 | A disposal request names the Sales Revenue account (4000) as the cash account, as the gain account, or an asset or revenue account that is not a cash book as the cash account | Refused with a 400 and a reason (`cash_account_not_allowed`, or the existing gain/loss token for the gain); nothing posts (FR-FA26). A gain sent to "Other income" or the gain-on-disposal account is accepted |
| UC-FA30 | An accountant records a disposal by manual journal | The journal posts, but the Owner Admin is flagged that a fixed-asset account was touched outside the disposal route (FR-FA25, flag not block) |

## 6. Tasks (T) and order (O)

Rough estimates are the FA session's, to be replaced by GL's own. Every task is tests-first and one commit.

### 6.1 Foundations (no new rules about who may do what; safe to start first)

| Task | What | Owner | Extends | Estimate | Freeze status |
|---|---|---|---|---|---|
| **FS-1** | **DONE, no build needed.** The shared Period-belongs-to-the-Company check was closed by GL's T19 / RBAC F9 (commit 191fd9f, 2026-10-08, live since) and pinned by tests (FR-FA9). Recorded as done by GL, 2026-10-13 | GL | statement G1, SPUTO T19 | done | n/a |
| **FS-2** | Register tied to the ledger: V31 columns, link on create, reconciliation fields on the register response, one-off reported backfill; repair path for unlinked assets | GL, WEB display | GL link SPUTO P1 to P4 | as GL's own SPUTO | Not an RBAC change |
| **FS-3** | Actor on every FA action and first writers of `AuditLogEntry` (interim GL-local shape if T17 not ready) | GL, EA (T17) | statement G2 | 1 to 1.5 days (EA: T17 is not written yet; when it is, it is a minimal shared record of who, when, which Company, what action, request key; keep the interim fields compatible with that list) | Frozen only if it changes who may do what; adding an actor does not |
| **FS-4** | Per-year depreciation guard: asset records the last year depreciated; second charge refused; Flyway migration, tests including double-call | GL | FR-FA6 (new) | 1 day | Not an RBAC change; fixes a money bug |
| **FS-5** | A void/correct path for an asset (acquisition reversed and the asset removed from the register, with a reason), so the manual-journal block (FS-10) cannot strand a legitimate correction | GL | GL link SPUTO open question 2 | 1 to 2 days | Built first as a plain WRITE action (actor and reason recorded); re-gated as a request through FS-7 once FS-7 exists |
| **FS-14** | **BUILT as tests only** (GL branch `gl/fa-role-matrix-tests`, tip 2986e72, with CM, mutation-checked 6 of 6): a READ member is refused on all four writes with nothing posted and the two reads still answer 200; no token (401) or no membership (401 or 403, depending on whether EA knows the person) is refused on all six routes; wrong Company in every combination is refused (403, and 404 for the F-FA1 shape: A's Period, B's asset, B's accounts) with nothing posted; plus a positive control. CM carved it out of the freeze 2026-10-13 | GL | statement G7 | done, awaiting CM's merge | tests only |

### 6.2 The approval spine (needs GL's single shared pending-action mechanism and EA's capability set)

| Task | What | Owner | Extends | Estimate | Waits for |
|---|---|---|---|---|---|
| **FS-6a** | Evidence fields on acquisition (reference, ownership reference for already-owned), uniqueness per Company, refused when missing | GL | FR-FA1 | 1 to 1.5 days | none (can precede approval; closes A1 partly) |
| **FS-7** | Disposal and acquisition become request then approve with the immutable stored payload; approve carries no figures; approver is the Owner Admin (self-approval flagged); batch form for imports (FR-FA15). Impairment (with its evidence note, FR-FA16) is in the same step; fail-closed behaviour (FR-FA18, UC-FA20) is tested here | GL | statement G3, T12, FR-FA2 to FR-FA5, FR-FA15 | 3 to 5 days | GL's pending-action mechanism (GL confirmed 2026-10-13: **none exists yet**; `PostingStatus` has a PENDING state but no use case or route drives it; T12 is design only, and FA will not pick a shape for it). Approver check: the approver must be the Owner Admin of the Tenant (D-FA-A). Before T5a, that uses `isOwnerAdmin`, which `/me` carries today, so for acquisitions the interim check is already the target rule and no weaker; T5a later replaces it with the approve capability held by the Owner Admin. The Owner Admin as requester: self-approval, recorded and flagged (D-FA-F, decided). Disposals and impairments: the approver is the Owner Admin too (D-FA-G, decided). **Ships behind a flag, OFF by default** (the RBAC rule: design now, enforce after the features exist), and is switched on per Company |
| **FS-8** | Dates validated against the period (A12): acquisition and disposal dates must fall in the period they post to, or be refused. GL confirms this is new shared code for every posting route, not an FA-only fix | GL | FR-FA9 sibling; `docs/GL_Period_Management_Scoping.md` L1 to L3 | 0.5 day for FA's routes; the shared version is GL's call | Femi's answer on GL's period scoping |
| **FS-9** | Disposal evidence (sale invoice or receipt reference) and the clearing-account check that proceeds were matched to cash | GL | A8 | 1 day | FS-7 |

### 6.3 Closing the remaining doors

| Task | What | Owner | Extends | Estimate | Waits for |
|---|---|---|---|---|---|
| **FS-10** | Manual journals refused on 1200, accumulated depreciation and accumulated impairment, using `ModuleOwnedAccounts`; message names the screen to use | GL | FR-FA8 | 0.5 to 1 day | **FS-5** (a way to correct must exist first); coordinate with GL's journal RBAC statement |
| **FS-11** | Service credentials refused on FA mutations (importer batch excepted, and via FS-7) | GL, EA, CM | statement G6, F-FA3, T15/D5 | small | the per-credential model (T15) |
| **FS-12** | Policy: useful-life ranges per category, minimum capitalisation cost, ADMIN-set, audited, per Company | GL, EA (first real ADMIN use) | FR-FA7 | 2 days | FS-3, FS-7 |
| **FS-13** | Detective: Owner attention items via the approved dashboard "Needs your attention". **Pending requests** ride EA's existing approvals-queue as one more source (a GL read of pending fixed-asset requests, consumer-first, like SOP, IM, POP, HR today). **Counts** (assets not depreciated this year, unmatched disposal proceeds, Suspense balance, big impairment) need small GL read routes whose shape GL defines (like `receivables-payables-summary`); EA then adds an optional dashboard field after WEB declares it. Order: GL read routes first, FA tells EA the shapes, EA adds the fields | GL routes, EA dashboard, WEB declares | FR-FA10 | 2 days | FS-2, FS-4, FS-7, EA dashboard first slice (WEB's attention box over the approvals queue) and Femi's approval of this Playbook |
| **FS-17** | Company-wide depreciation run: one action depreciates every eligible asset of the Company for a year, skips those already depreciated that year (FS-4), and reports what it did and skipped; no approval (formulaic, objection O1); WEB button through FS-15 | GL | UC-FA10, FR-FA6 | 1 to 2 days | FS-4 |
| **FS-24** | Type checks on the disposal accounts as FR-FA26 sets them (GL's proposal, accepted): cash must be a cash or bank book; fixed-asset and accumulated-depreciation accounts asset-type, active, not a cash book, not another module's control account; gain account not Sales 4000; refusal tokens as in the error-code table; tests first in the shape of the loss-account tests, with a mutation check on each rule | GL | FR-FA26, finding F22-20 | 0.5 to 1 day; GL accepted it 24 Oct, queued behind GL's current items, CM sets the order | none; validation, not an authorization change |

### 6.4 Surfaces

| Task | What | Owner | Estimate | Waits for |
|---|---|---|---|---|
| **FS-15** | WEB: capability-gated buttons, request and approve forms, pending list, honest "waiting for approval" status, tie-to-ledger display | FiSH+ER WEB | 2 to 3 days | FS-7 contract; T5a; R11 |
| **FS-16** | Phase 2 (POP facts, 2026-10-13: a PO is verifiable by id today, `GET /companies/{c}/purchase-orders/{id}` returns `poNumber`, status and total, MATCHED = three-way matched, CLOSED = paid; by PO number or invoice reference there is no route, a read-only lookup is about 0.5 day, additive; `invoiceReference` is typed text at match time, so it proves POP matched an invoice with that text, not that the supplier issued it; calling POP as a module needs its own service credential, CM's domain; POP has no capital-item marker on a line; a matched purchase is booked to one account that GL resolves to Expense today, so a capital purchase would be booked to expense until per-line account routing (GRNI posting-plan work, scheduled, not built) exists; Seam A is a known open fault) PO-driven acquisition: an approved and three-way-matched POP purchase of a capital item creates the pending FA request itself, so the evidence is POP's, not typed | POP, GL | design first | POP's three-way match; FS-7 |

### 6.5 Dependency order (foundations first)

```
Tier 0  foundations, safe, no new rules      FS-4  FS-8  FS-3  FS-2  FS-6a    (FS-1 done; FS-14 built as tests, awaiting CM's merge)
                                               |
Tier 1  needed before blocking anything       FS-5 (void/correct path)
                                               |
Tier 2  the approval spine                    GL pending-action mechanism (T12)  +  EA T5a, T6, T17
                                               |
                                              FS-7 -> FS-9
                                               |
Tier 3  close remaining doors, detect         FS-10  FS-11  FS-12  FS-13  FS-17
                                               |
Tier 4  surfaces and later                    FS-15  FS-16 (Phase 2)
```

Why this order: Tier 0 fixes real integrity and money bugs and needs no one's permission model to change. FS-5 comes before FS-10 because blocking manual journals without a way to correct an asset would strand real accountants. The spine (FS-7) is the answer to the acquisition gap and waits for GL's shared mechanism and EA's capability set; **it is the item Femi cares most about, so FS-6a (evidence) and FS-8 (dates) are pulled forward as the part of the gap that can close before the freeze lifts**, if CM agrees they are not RBAC changes.

### 6.6 Internal-control extensions (Femi answered 2026-10-23: FR-FA20, FR-FA21, FR-FA22, FR-FA23 AGREED; FR-FA19 and FR-FA24 PARKED until after MVP)

Femi, 2026-10-23: put systems in place, as far as we can possibly do, to prevent the owner of a business from being defrauded, by integrating good-quality internal control into FiSH. Approval (sections 4 and 6.2) controls what gets **posted**. Fraud against an owner also happens around the posting: an asset that never existed, a real asset that quietly disappears, a sale to a friend, a change nobody told the owner about. These proposals cover that. They target everyone except the owner; the owner's own entries are recorded and flagged, never blocked.

| ID | Control (requirement and task) | Fraud it answers | Needs | Task |
|---|---|---|---|---|
| FR-FA19 **(PARKED until after MVP, Femi 2026-10-23)** | **The owner hears about every fixed-asset movement.** Every request, approval, rejection and posting reaches the Owner Admin (the attention list, plus an optional email or push digest), including actions that need no approval, such as depreciation. Nothing in FA changes silently. Detective | Staff acting where the owner never looks; a change slipped in between two reviews | FS-3 (actor), FS-13 channel, EA/WEB notification | FS-18 |
| FR-FA20 **(AGREED, Femi 2026-10-23)** | **One serial or registration number, one asset.** An identifier, where given, is unique per Company; a duplicate is refused or flagged to the approver | The same item booked twice; ghost duplicates | Small; ships with FS-6a | FS-19 |
| FR-FA21 **(AGREED, Femi 2026-10-23)** | **Every asset has a custodian and a location.** A named person (from the Organisation's people list) and a place; a change of custodian or location is logged and shown to the owner | Nobody answerable for an asset; assets that wander | New fields and a migration; people list from HR/EA | FS-20 |
| FR-FA22 **(AGREED, Femi 2026-10-23: "a good habit for them to develop")** | **Periodic physical verification.** The owner (or a reviewer they name) starts a verification round; each custodian confirms in writing, with the actor and time, that each asset exists, its condition and its place (an optional photo when FiSH has an attachments facility); assets not confirmed within a set time are listed to the owner and flagged for impairment or disposal review. Software cannot see the building, but it can make a person confirm, on the record, which is how ghost assets are found | Ghost assets; assets sold or stolen and left on the register | FR-FA21, FS-3; WEB screens; GL read and write | FS-21 |
| FR-FA23 **(AGREED, Femi 2026-10-23: "Fantastic idea")** | **Disposal red flags shown to the approver.** The buyer is a required field; flagged when proceeds are below net book value by more than a set percentage, when the buyer matches a current or former member of staff (when the people list can be read), or when the person who requested the sale also recorded the cash receipt (FS-9). The approver still only approves or rejects | Selling a real asset cheaply to a friend or to oneself; pocketing the proceeds | FS-7, FS-9; a read of the people list | FS-22 |
| FR-FA24 **(PARKED until after MVP, Femi 2026-10-23)** | **Unusual-pattern flags (detective, attention list only, never blocking):** acquisitions just before a period end, round-number costs, several purchases just under a figure the owner names | Padding a period; testing the controls | FS-13 channel | FS-23 |

Order now: FR-FA20 first (small, ships with FS-6a: FS-19), then FR-FA21 (custodian and location: FS-20), then FR-FA22 (verification rounds: FS-21, which needs FR-FA21 and FS-3). FS-18 (FR-FA19) and FS-23 (FR-FA24) are parked until after MVP; FS-22 (FR-FA23, agreed) follows once the disposal request flow (FS-7) and FS-9 exist. The owner still sees pending requests in the attention list through FS-13, which is not parked. Use cases: UC-FA26 (a ghost asset is found by a verification round), UC-FA27 (a disposal to an employee at half book value is flagged to the approver, FR-FA23, agreed), UC-FA28 (a second asset with the same serial number is refused or flagged).

## 7. Questions for Femi (plain language)

1. **D-FA-A. RESOLVED 2026-10-13 (Femi): every asset purchase, at any amount, requires approval from the Owner Admin.**
2. **D-FA-B. Impairments go through the Owner Admin's approval: CONFIRMED yes (2026-10-13, "the owner is the final authority"). Still to confirm, Femi: does "the approver cannot change the figures" also apply to impairments** (writing an asset down)? Default design, kept meanwhile: yes (the safer rule, same reasoning as disposal). Not blocking.
3. **D-FA-C. (POP can already confirm a purchase order by its id; checking by invoice reference needs a small new POP route, and even then it proves only that POP matched an invoice with that text.) Until POP can check supplier invoices, may the invoice reference be typed text** (but unique per Company and required), or must acquisitions wait for POP's matched purchase before they are accepted? Recommended: typed text, required and unique, now; matched purchase as the later, stronger rule.
4. **D-FA-D. May manual journals to the fixed asset accounts be blocked?** Today an accountant could post straight to them. Blocking is safer, but only after a proper correction path exists (FS-5). **Updated 24 Oct (finding F22-20):** Femi's rule is that the owner's own entries are flagged, never blocked, and GL is scoping a flag for manual journal lines on revenue accounts. So D-FA-D is best put as: flag any manual journal that touches a fixed-asset account to the Owner Admin (recommended, consistent with the rule), and block only for staff if you want that too. Not decided.
5. **D-FA-E. Useful-life ranges and a minimum asset cost: should the platform enforce them, or just warn the approver?** Recommended: warn first, enforce later.
6. **D-FA-F. DECIDED (Femi's rule "The owner is the final authority", via CM, 2026-10-13): when the Owner Admin buys an asset they remain the approver; self-approval is recorded and flagged in the attention list and the audit.** Delegate option dropped. Honest limit, kept on purpose: with self-approval, the Owner Admin's own purchases are the one place this design cannot stop a false asset; it can only make it visible. Femi, 2026-10-23: "It is not up to us to police the Owner of a Business." So this limit is intended, not a gap to close.
7. **D-FA-G. DECIDED (same rule, 2026-10-13): the Owner Admin approves disposals and impairments too,** with the same fixed-at-request rule.
8. **D-FA-H. ANSWERED 2026-10-23 (Femi):** FR-FA20, FR-FA21, FR-FA22 and FR-FA23 agreed; FR-FA19 and FR-FA24 parked until after MVP. (FR-FA23's first reply restated that the Owner Admin approves disposals; after a plain example of the warning notes he agreed: "Fantastic idea".)

## 8. What this does and does not secure

It makes it hard to put a false asset, a false write-down or a false sale into the books without a second person seeing the exact figures, and it makes what slips through visible. It does **not** make an approver honest or stop two people colluding, and it does not see the building: whether an asset physically exists is checked by a person, and FR-FA22 (proposed) makes that check a recorded, attributable round rather than a hope. The Owner's own entries stay possible by design and are recorded and flagged, not blocked: we protect the owner from being defrauded, we do not police the owner. The approval step is only as good as the evidence it is shown, which is why evidence (FR-FA1) is part of the same gap, not a separate nicety.

## 9. Coordination and status

- **GL (code owner, replied 2026-10-13):** reports FS-1 already done (T19) and FS-14 built as tests (`gl/fa-role-matrix-tests`, tip 2986e72, with CM); takes FS-3 to FS-6a and FS-7 to FS-13 once Femi approves this Playbook and CM gives the go, and will size them then. Confirmed the three readings. Needs the pending-action mechanism (T12) decided first.
- **EA (replied 2026-10-13):** T5a is a platform contract change, not a small one: capabilities are added additively on `/me`, which five services decode strictly, so GL, POP, SOP, IM, HR and WEB must declare the field first, then EA ships, then a legacy-level migration maps each existing level to the full set it implied so nothing changes on day one. It is behind the RBAC freeze, starts only when Femi decides and CM reviews at HIGH, no date. FS-7 therefore cannot rely on it at first (see FS-7's interim check). T6 is largely true already (the Owner Admin has had an explicit ADMIN-with-all-modules assignment at each Company since 2026-09-23); what remains is a guard that the approver capability cannot be removed from the Owner and a backfill for Companies with no assignment, both waiting on the read-only production check T23 (Femi/CM). T17: EA owns it, not written. FS-13: see that row.
- **WEB:** FS-15.
- **POP (replied 2026-10-13):** can verify a PO by id now; a lookup by PO number or invoice reference is a 0.5-day read route if wanted; Phase 2 needs a capital-item marker, per-line account routing (GRNI work) and FS-16's pending-request route. Anything requested goes through CM's backlog and coordination doc, and POP then claims a row.
- **CM:** carve-out of FS-14 (ruled and done 2026-10-13; FS-1 needed none, T19 had closed it) (and whether FS-4, FS-6a, FS-8 count as RBAC changes); register this Playbook's row; sequencing against the freeze; no code until Femi approves.
- **Row for the Playbook definition's status table:** FA (code in GL, screen in WEB): operator sheet = section 1 of this document; S/P/U = sections 2, 4, 5; T/O = section 6.

## 10. Verification log

Read on 2026-10-13 against GL `ccddf1b`: `FixedAssetRoutes.kt` (error mapping, `respondIdempotently`), `CreateFixedAssetUseCase`, `RecordFixedAssetDepreciationUseCase`, `fixed_asset.kt` (`recordDepreciation`: no per-year or per-period record), `module_owned_accounts.kt` and its three call sites (cash-book entry, undo, counter-account list only; **not** the journal route), `PostJournalEntryUseCase` (checks the Company ownership of accounts and period; no module-owned-account check found).

**Not verified, flagged:** that a manual journal to 1200 is accepted (read by FA and GL, not run); the F-FA1 exploit (moot: T19 closed it before this Playbook existed). **Correction, 2026-10-13:** the first draft of this Playbook and `docs/RBAC_FA_Statement.md` listed F-FA1 as open. That was FA's error: the statement was written against GL `b4723da`, before T19 (191fd9f), and when FA re-read GL `ccddf1b` for this Playbook it did not notice that the three mutation use cases already call `findOwnedBy(request.periodId, fixedAsset.companyId)`. GL reported it; FA re-checked master (191fd9f is an ancestor of master, all three use cases carry the call, both guard tests exist) and corrected both documents. In the table in section 3 and FR-FA9 it is now stated as closed. FS-14's wording is also corrected: no membership is refused with 401 or 403, not always 403; how the Jenkins/ECS state of the live service matches master.

**Review, 2026-10-13 (reviewer's 14 findings, `docs/reports/Playbooks/TestPlans/FA_Security_Playbook_Review_2026-10-13.md`):** all fixed in this document except finding 12, which stays open until baseline check B1 confirms the manual-journal acceptance live (with Femi's approval, in the xyz Company only). Fixes: threat table task names (1), FS-5 gate (2), FS-14 wording (3), FR-FA9 narrowed to the Period check with the 401/403 membership refusal stated (4), A4/A6/A7 closed-by columns corrected (5, 6), FR-FA16 to FR-FA18 and UC-FA21 to UC-FA25 and FS-17 added (6 to 9), interim void stated (10), target error codes proposed (11), import-batch requester named (13). Finding 14: the Playbook is in the Playbooks folder; it is still DRAFT and not approved, so the Decisions Log correctly does not record it as approved.
