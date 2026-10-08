# RBAC across FiSH: Scope, Plan, Use cases, Tasks, Order (SPUTO)

**Owner:** Configuration Manager (CM). **Status:** DRAFT v0.3, 2026-10-08. **Trigger (Femi, 2026-10-08):** he withdrew the idea that the Owner Admin gets full ADMIN on every module ("full administrative access comes not only with read access but write access; the writing into financial data is wrong"), asked CM to write a full SPUTO on RBAC across the FiSH system, and then asked every peer to review, analyse and collaborate with CM on how it applies to them. Each runtime (Education Runtime/EduSys and the ones that follow) writes its own RBAC SPUTO as it comes onboard (the Education Runtime's is `docs/ER_RBAC_SPUTO.md`).

**What changed in v0.3.** The application round is under way: statements from EA, GL, POP, SOP, IM, FA and the Education Runtime are on master (`docs/RBAC_<Service>_Statement.md`; HR, WEB and Omniview are still to come). They corrected one finding (the Owner Admin is **not** at a bare READ floor, see F7), confirmed most of the others, and added six more (F9-F14). Femi's decisions D1-D4 and D6 (2026-10-08) are recorded in section 2; D5 and new decisions D7-D11 await him.

**Freeze while this is open:** no service changes its authorization model (role floors, owner uplifts, access levels, grants, new capabilities) without CM. Three carve-outs are authorised because they only **add a deny** and change no role: T1/T4 (fail-closed service verifiers), T19 (GL period/Company check) and T20 (IM bin/Company check). The unmerged EA branch `feat/ea-owner-admin-all-modules` is withdrawn.

**How this was produced.** A read-only code survey of all nine checkouts (2026-10-08), CM spot-checks against `origin/master` and the live task definitions, and then each peer's own statement re-verifying the findings against its master. Items marked **[verified]** were confirmed by CM or by the owning peer against master. File references are relative to the FiSH root.

---

## 1. Scope (the problem)

FiSH has seven services and a shared web app that each decide "may this person do this?" separately. They agree on the shape (EA `GET /me` reports the caller's Role, AccessLevel and module grants per Company) but not on what the words mean, who is trusted, or who may approve money. Femi's correction makes the gap explicit: **being an owner or administrator must not, by itself, let anyone write into financial data without that being a deliberate, visible grant.**

In scope: human authorization (roles, access levels, module grants, per-Company scoping), approvals and separation of duties, acting-identity recording, service-to-service identities, operator access (Omniview), the WEB app's use of the rules, and the extension contract for industry runtimes.

Out of scope here (own SPUTOs): the live-switch security scope (rate limiting, WAF, row-level security, backup/DR), end-customer identities (guardians, suppliers, customers), and each runtime's own role vocabulary (they write theirs).

### What the code does today (summary)

| Topic | Today |
|---|---|
| Identity | Every service uses the JWT `email` claim only (no `sub`). EA matches email exactly; ER lowercases staff subjects (case-insensitive since first-admin) but guardian matching stays exact; HR's owner match is exact. |
| Levels | EA `AccessLevel`: NONE < READ < WRITE < APPROVE < ADMIN compared by ordinal, so ADMIN implies WRITE and APPROVE. **Every service uses only READ and WRITE**; APPROVE is used in one place (HR leave); GL's ADMIN gate exists with no callers. |
| Decision | Services call EA `/me` per request; allow when the Company's level is high enough and the service's module is granted (GL enforces a module only on TAX routes). EA unreachable = 503 (fail closed). |
| Owner Admin | **Since 2026-09-23 EA registration gives the Owner an explicit OWNER_ADMIN assignment at ADMIN with every module except EDUCATION_RUNTIME at each Company (EA migration V15 carried older owners forward; test-confirmed on Postgres 16).** `/me` reports `role/accessLevel null` and no modules for a Company where he has no assignment; the READ floor exists only inside EA's `Membership.accessLevelAt`. SOP additionally lifts the Owner to WRITE+Sales (2026-10-06). HR approves payroll, expenses and advances by an exact-email "owner only" match. |
| Approvals | **No service has an approval step on money**, except HR's owner-only payroll/expense/advance approvals and IM's `StoreManager` Cognito group for adjustments/counts. POP, SOP, GL and ER (fees) let one WRITE caller create and complete the act. |
| Acting identity | **Not recorded** on sales, collections, returns, credit notes, POs, payments, stock movements, journal entries (GL `AuditLogEntry` has no writers), except invoice-email `sentBy` and HR's optional `submittedBy`/`decidedBy`. |
| Service accounts | GL, IM, SOP skip EA membership for service tokens. A service token is bound to **no Tenant, no Company and no endpoint set**. |
| ER | Own model: `staff_assignments` with free-form role strings; EA seeds only the first admin (live since 2026-10-08). |
| WEB | Hides/shows by `isOwnerAdmin` and the granted-module list; never by access level. |

### Findings that drive the plan

Severity is CM's reading for a system that will hold real money. **[v]** = verified against master by CM or the owning peer.

- **F1 (HIGH, [v]) fail-open service verifiers.** `serviceVerifier ?: verifier` in GL (`Application.kt:498`, also the `= verifier` defaults in `installFishJwtAuth`, `Auth.kt:110-124`), IM (`:268`) and SOP (`:387`): if a service-audience variable is unset, a *human* token is registered as a service account and skips EA membership. CM checked the live task definitions: all audience variables are set today, so it is **latent, not exploitable now**. IM reports it is not exploitable as built (Ktor tries the human provider first) but that rests on provider order nothing pins. ER and POP have no such fall-back (ER starts quietly with an audience unset: T-ER9).
- **F2 (HIGH, [v]) SOP trusts body fields for the approving authority**: `approvedBy` on a customer-cancellation return (`ReturnRequestRoutes.kt:145`) and, same class, `confirmedBy` on the legacy `POST /record-sale` (`SalesOrderRoutes.kt:68`) (F2b).
- **F3 (HIGH, [v]) money can be created and completed by one person**, and no actor is recorded: POP approval (WRITE only; the approval **threshold is editable with WRITE**; **no threshold = no approval**), POP payment and three-way match (no approval step at all), POP returns outwards; SOP credit notes, cancellation after fulfilment, Bill collections; IM receipts/issues/adjustments (a WRITE caller alone chooses the contra account and the Item's asset/cost accounts); GL postings (no approval step on any route); HR payroll (owner-only, but submitter and decider may be the same person; a WRITE delegate can set initial pay and bank details on create).
- **F4 (HIGH, [v]) ER staff management**: a REGISTRAR can make anyone SCHOOL_ADMIN and demote or revoke an existing admin (`canManageRegister`); role strings are free-form and matched by exact case; `SCHOOL_ADMIN` bundles all four capabilities (conflicts with D1).
- **F5 (MEDIUM) EA delegation is uncapped.** An HR_OFFICER at ADMIN can invite staff up to ADMIN with any modules and edit their own modules; re-inviting an ACTIVE member is a no-op.
- **F6 (MEDIUM, [v]) service tokens are blanket**, and wider than first thought in GL: not bound to a Tenant **nor to an endpoint set**, so any of GL's four credentials can call every route (journal entries, account creation and re-tagging, opening balances, imports) that SOP, POP, IM and HR do not need. GL still requires and compares `X-Tenant-Id`, but against the Tenant of the body's Company. POP, SOP, IM and HR still fix one Tenant at deploy time. SOP uses one app client for both GL and EA owner-contact.
- **F7 (CORRECTED, [v] by EA) the Owner Admin default.** v0.2 said he sits at a bare READ floor with no modules. EA's statement shows registration has given him explicit ADMIN-with-all-modules assignments since 2026-09-23 (T6 is largely **already done**); only a Company with no assignment shows `null`. The real inconsistency is how services read `null`: GL and SOP treat it as READ (SOP's modules are then empty, so effectively NONE), POP, IM and HR as NONE, HR as READ for the Owner. Production rows still need a read-only check (script ready for Femi: `ea_owner_assignments.sql`).
- **F8 (MEDIUM) ER student read has no per-child guardian check** (narrower than first thought: id, name, class, photo, `hasSafeguardingFlag`); the DPID device role resolves at whatever school is in the URL; **EA operator tokens have no length rule or throttle** (Omniview's do).
- **F9 (HIGH, [v] by GL) cross-Company/cross-Tenant write integrity in GL.** About 30 posting routes authorize at the body `companyId` but take the Period's Company from the body `periodId`; the use cases compare accounts to that Period only. A caller authorized at Company A who supplies Company B's period and account UUIDs posts into B's books (a different Tenant if B is in one); `X-Tenant-Id` is compared with the body Company's Tenant, so it does not stop it. Needs B's UUIDs, so hard to exploit, but it is a P6 breach. **T19 is authorised.**
- **F10 (MEDIUM, [v] by IM) IM `receive` accepts a body `binId`** and creates a balance for it without checking the bin exists or belongs to the path Company. **T20 is authorised.**
- **F11 (HIGH, [v] by ER) a linked guardian can mark their own child's invoice PAID** via `POST /parent/invoices/{id}/pay` (a stub that writes `StudentPaymentReceived` to ER's outbox). No money moves today because nothing relays the outbox; payment confirmation must come from a provider or bank record **before any relay exists**. The whole ER fee loop (define schedule, issue, resolve guardian, confirm payment, reconcile) is one predicate, `canManageFees`.
- **F12 (MEDIUM, [v] by SOP) SOP facility limits** are opened with WRITE and read Tenant-wide (R3 says ADMIN-only); **no acting identity** on any SOP money act (`requestedByEmail` is read, not stored); the aval authority is the constant `SALES_ADMIN`.
- **F13 (MEDIUM, [v] by IM) the `StoreManager` group is pool-wide**, not per Company and invisible in EA; creator and approver may be the same person.
- **F14 (fixed) ER→SOP flat route.** ER's guardian-to-customer call posted to `/api/customers`, removed from SOP on 2026-09-30 (every call 404); also its strict decoder could not read SOP's 201. Fixed by the Education Runtime (fix released with this version).
- **F15 (MEDIUM, GL) reference data has no role**: jurisdictions, `vat_rates` (verified flag) and the proposed exempt-only flag post to every tenant's books with no platform-operator capability guarding them.

---

## 2. Plan (principles and requirements, SRS)

### Principles

- **P1 Read and write are different powers.** Seeing everything never implies posting anything. *(Femi, 2026-10-08.)*
- **P2 Authority is held through explicit roles, never implied by a title.** The Owner is the Boss and is given every role at registration as visible assignments (D4); no blanket uplift anywhere. *(Femi, 2026-10-08.)*
- **P3 Separation of duties on money.** For any record that moves money or stock value, the person who creates it is not the person who approves it, and both are recorded. The Owner is exempt (D6): his self-approval is allowed and flagged.
- **P4 Fail closed.** No fall-back verifier, no default grant. Unknown caller, unknown Company, missing configuration = deny.
- **P5 One vocabulary.** The capabilities and module grants mean the same thing in every service (R1).
- **P6 Per-Company everywhere.** A decision is made at the record's own Company, and **every id in a request (period, account, bin, supplier, customer) is checked to belong to that Company**; the Tenant comes from the Company, never from the caller or a deploy-time value.
- **P7 Service identities are scoped.** A service credential acts for a stated Tenant (D5, pending) and calls only the endpoints its role needs.
- **P8 The server decides.** The UI may hide controls but never relies on hiding.
- **P9 Everything is attributable.** Create, approve, reject, override and role change record the acting identity (stable user id plus canonical email) in the same transaction as the act.
- **P10 Industry runtimes extend, they do not fork.** A runtime maps its own roles onto the platform capabilities and writes its own RBAC SPUTO.

### Requirements (R-numbers are for the tasks)

- **R1 Capabilities (the model).** Authorization is a **set of capabilities per Company and module**, not one ordered level: *read* (non-financial detail), *view-financial* (balances, reports, receivables), *write* (create/edit operational records, never approve), *approve* (approve or reject another person's money-affecting record, including voids, waivers, refunds and write-offs), *administer* (grant roles, set thresholds/policy/configuration; never posts or approves). **Migration (B1):** each legacy level maps to the full set it implied (READ → {read, view-financial}; WRITE → + write; APPROVE → + approve; ADMIN → + administer, i.e. **everything it implied**), so **day one changes nothing for anyone**; only assignments created afterwards can be narrower. Consumers declare the new field first (strict decoding). Until each consumer has moved, the old level stays on the wire.
- **R2 Approvals.** Every approval route requires the approve capability (not write), refuses when approver = creator **except for the Owner** (self-approval allowed and flagged in the audit record, D6), and stores the approver's identity from the token, never from a body field. **A service principal may enter a record but NEVER approve one**; service-originated money acts carry an `actedBy` block (the origin system's stable user id and role) stored beside the service identity (B3).
- **R3 Thresholds and policy** (POP approval threshold and tolerance, HR expense policy, tax settings, SOP facility limits, IM contra-account and Item account mapping, GL limits) are *administer*-only and audited with before/after.
- **R4 Owner Admin (decided).** At registration of a Company, EA gives the Owner every role at that Company as explicit assignments (post, approve, administer, per module). The approver role cannot be removed from the Owner. Everything EA reports for the Owner comes from those assignments; no service applies a local uplift. SOP's 2026-10-06 Sales WRITE uplift is removed once the assignments exist **and are backfilled for every existing Company**.
- **R5 Delegation is capped.** A delegate can grant at most their own capabilities, only for Companies they administer, never to themselves; ER's staff routes the same (no REGISTRAR→SCHOOL_ADMIN).
- **R6 Fail closed.** A human verifier never doubles as a service provider; when a required service audience is unset the service **registers a deny-all service provider** (service routes reject every token) and logs a loud warning at start-up (SOP's proposal, accepted; it keeps non-ER deployments starting).
- **R7 Service accounts.** Each service credential is bound to a declared Tenant (and optionally Company set) **and to an explicit endpoint allow-list** (the cheapest, highest-value control in GL), with a distinct app client and audience per recipient (B5); the Tenant header (or equivalent) is validated, not trusted. GL's options note (`docs/GL_Tenant_Header_Service_Account_Options.md`) is input. Settle the credential model **before** Epic 13 builds ER's inbox into SOP, so the inbox is the first user of a scoped credential.
- **R8 Consistent fall-backs.** A Company absent from `/me`, or with null/empty grants, is NONE for everyone including the Owner. (T4 must follow the Owner assignments, or it recreates the 2026-09-28 bug in GL.)
- **R9 Identity.** One canonical email form (trim + lower-case) applied at the token boundary; matching case-insensitive; the stable user id from `/me` is recorded alongside for audit.
- **R10 Audit.** A shared minimum audit record (who: user id + email, what, which Company, when, before/after for role and threshold changes, `selfApproved` flag), **written in the same transaction as the act**. A missing row after a successful act is a defect. Records predating it have a null creator and are treated as "allow" for approval.
- **R11 WEB.** Controls are shown by capability from `/me`, not by `isOwnerAdmin`; stale READ-floor comments removed; the self-approval flag displayed.
- **R12 Runtime contract.** A runtime declares: its role names, how each maps to the platform capabilities (view, enter, approve, administer), its service identities, and where it keeps role data; it must meet R2-R10 for its own approvals.
- **R13 Operators.** Operator tokens: minimum length, throttle, named per operator (EA to match Omniview); two-person rule for destructive/exposing actions.
- **R14 Platform operator capability** for reference data (jurisdictions, VAT rates, exempt-only flag) that posts to every tenant's books.
- **R15 Money actions never come from a stub.** Payment confirmation (F11) comes from a provider/bank record; no endpoint callable by a guardian marks an invoice paid.

### Decisions (Femi, 2026-10-08)

| # | Question | Femi's answer | Recorded as |
|---|---|---|---|
| D1 | Is ADMIN "administer access and configuration only", with no posting and no approving? | **Yes.** | ADMIN never includes posting or approving (R1). |
| D2 | Who may approve money records? | The Owner Admin **holds the approver role from the beginning and cannot take himself out of it**; he can delegate approval. | R2, R4. |
| D3 | The Owner Admin's default at a Company? | "He is the Owner, the CEO, the Boss." | R4: every role, as explicit assignments. |
| D4 | May the Owner Admin do day-to-day posting? | He may delegate it, but as a single user he will do everything himself. **Clarified: "explicit role, created automatically".** | R4: nothing implicit, everything auditable. |
| D6 | One-person business: block or allow creator = approver? | The creator is the Owner, so he cannot be blocked; he may delegate to an employee. | R2: rule applies to employees; the Owner's self-approval allowed and flagged. |

### Decisions still needed from Femi

| # | Decision | CM recommendation |
|---|---|---|
| D5 | **Service credential scope**: a service credential is the login one FiSH service uses to call another (e.g. SOP posting to GL). Limit it to **one Tenant**, a list, or all? | One Tenant per credential, plus an endpoint allow-list. |
| D7 | **Which acts need a second person?** SOP proposes yes for credit notes, cancellation after fulfilment, Bill collections, write-offs; no for ordinary/cash sales and collections. IM asks whether ordinary stock movements need an approver or only write-offs and counts. POP asks about **payment, three-way match and returns outwards**. GL proposes manual journals above a limit, fixed-asset disposal/impairment, opening balances/imports, reversals and period close. | Approval for anything that reduces receivables/revenue or stock value, moves cash out, or changes the books after the fact; none for the Owner's own routine sales and receipts. |
| D8 | **POP: "no threshold = no approval"** (today's default for every Company): keep it, or require every Company to set one? | Keep it, and prompt the Owner to set one. |
| D9 | **Is "view financial data" its own capability** (balances, receivables, reports), separate from read? | Yes (R1). |
| D10 | **Limits**: the GL manual-journal limit; whether fixed-asset acquisition needs approval above a limit; whether the approver may amend proceeds/date on a disposal. | Per-Company limit set by the Owner; acquisitions approved above the limit; the approver may not amend, only approve/reject. |
| D11 | Education Runtime: D-ER1 to D-ER7 in `docs/ER_RBAC_SPUTO.md` (e.g. who approves results, fee waiver approver, form-master). Also the offline-mark **deadline rule** (arrival time vs capture time). | Femi decides the ER ones with the ER session; capture time bounded to a few days for the deadline. |

---

## 3. Use cases

| UC | Actor | Main flow | Rule |
|---|---|---|---|
| UC-R1 | Owner Admin | Sees dashboards, ledgers, reports, staff, configuration at every Company of the Tenant | his explicit assignments (R4) |
| UC-R2 | Accountant / officer | Creates and edits operational records (sales, POs, journals, adjustments) | write at the Company with the module granted |
| UC-R3 | Approver (the Owner, or someone he delegates to) | Approves or rejects a record (PO, return/credit note, adjustment, payroll, expense, disposal, manual journal) | approve capability; for employees creator != approver; the Owner's self-approval allowed and flagged (R2/D6); approver stored from the token |
| UC-R4 | HR officer / Owner | Invites staff and assigns Company roles | R5 cap; cannot self-escalate; audited |
| UC-R5 | Service (POP/SOP/IM/HR/ER → GL, IM, SOP; EA → ER) | Posts or reads on behalf of a Tenant | R7 scoped credential + endpoint allow-list; may enter but never approve; `actedBy` recorded |
| UC-R6 | Runtime user (School Admin, Registrar, Teacher, Guardian) | Acts inside the runtime | runtime roles mapped per R12; approvals follow P3 in the runtime |
| UC-R7 | Support operator (Omniview) | Handles tickets, diagnostics with consent | R13; two-person rule; access log |
| UC-R8 | Auditor / read-only viewer | Reads within a granted module | read, plus view-financial only if granted; no write controls shown (R11) |
| UC-R9 | A one-person business | Owner does everything | D4/D6: explicit roles created at registration; self-approval allowed and flagged |
| UC-R10 | Platform operator | Maintains reference data (jurisdictions, VAT rates) | R14 |

---

## 4. Tasks (dependency-ordered; owner in brackets)

Femi has decided D1-D4 and D6 (D5, D7-D11 pending). **(add-a-deny)** = authorised now because it only adds a refusal and changes no role. Everything else waits for the decisions above.

**Authorised now (add-a-deny, no role changes)**
- **T1 (add-a-deny) Fail-closed service verifiers (R6):** deny-all provider when the audience is unset in GL, IM, SOP (ER: T-ER9); pin it with a test that a human token is refused on a service-only route. [GL, IM, SOP, ER sessions; CM reviews, HIGH-ish]
- **T4 (add-a-deny, SOP now; GL after T6 data check) Explicit NONE for a Company absent from `/me`** (R8). [SOP now; GL after the production check below]
- **T19 (add-a-deny, GO) GL period/Company check:** every body-periodId route (including fixed-asset actions) refuses a Period or account that does not belong to the authorized Company, same not-found shape, service callers included, cross-Company test per route family first. [GL; HIGH; in progress]
- **T20 (add-a-deny, GO) IM `receive` bin check** and every other body-supplied id in IM routes. [IM; HIGH-ish; in progress]
- **T21 (add-a-deny) ER: remove or gate the guardian "pay" stub** (F11) before any outbox relay exists; staff routes cannot grant a role the grantor does not hold (R5). [ER; HIGH]

**Foundation (no policy decision, but needs CM go)**
- **T2 Canonical case-insensitive email matching** at the boundary in EA/HR/SOP (ER done). [EA decides the matching rule first; HIGH]
- **T3 EA operator tokens:** minimum length, throttle, named per operator. [EA]
- **T22 Record the acting identity (S-T1, P9/R10):** an additive audit table or columns, written in the **same transaction** as the act, using `/me`'s `userId` plus the canonical email. Start with POP (T9a: `pop_audit_log`), SOP, IM, GL (`AuditLogEntry` has zero writers), HR. A prerequisite for any creator != approver rule. [each service; EA defines the shared shape]
- **T23 Production check of the Owner assignments** (read-only; script `ea_owner_assignments.sql` for Femi to run): decides T6 completeness, SOP's T7 and GL's T4. [CM/Femi]

**Capability model (after D7-D10, consumers-first)**
- **T5 Settled capability definitions** (R1 text) signed off by Femi. [CM]
- **T5a EA: capability set + migration.** Legacy level → the full set it implied (B1), reported on `/me` additively; five-deploy rollout in EA's statement; every consumer (GL, POP, SOP, IM, HR, WEB) declares the new field first. [EA, then all; HIGH]
- **T6 EA: "approver role cannot be removed from the Owner"** and the backfill check; registration already creates his assignments. [EA; HIGH]
- **T7 SOP: remove the Sales WRITE uplift** only after T5a/T6 and the production check (it also decides which Companies a person may list). [SOP, WEB]

**Separation of duties and limits (after D7-D10)**
- **T8 SOP:** derive `approvedBy` and `confirmedBy` from the caller (approve capability), accept-and-ignore the body field for one release so WEB does not break, creator != approver for employees, Owner exempt and flagged. Facility limits administer-only (F12). [SOP; HIGH]
- **T9b POP:** approve requires the approve capability; `PUT purchase-order-settings` requires administer; creator != approver; payment and match per D7. [POP; HIGH]
- **T10 HR:** `submittedBy` != `decidedBy` (Owner exception); initial pay and bank details on create owner/administer-only. [HR; HIGH]
- **T11 IM:** adjustment and stock-count approval uses the EA approve capability instead of the pool-wide `StoreManager` group; contra account and Item account mapping administer-only per D7. [IM; HIGH]
- **T12 GL:** approvals for manual journals above a limit, fixed-asset disposal/impairment (and reversal), opening balances/imports, reversals and period close (one shared pending-action mechanism); `ADMIN` guards account/period configuration, re-tagging and (when built) period management. Integration postings are not re-approved in GL: approval lives in the source service. [GL, FA; HIGH]
- **T13 ER:** as in `docs/ER_RBAC_SPUTO.md`: closed role list, four capabilities split out of `SCHOOL_ADMIN`, approval chain for results, `APPROVE_RESULTS`/`RELEASE_RESULTS`, fee issue != payment confirm. [ER; HIGH]

**Delegation, services, operators (after D5)**
- **T14 EA:** cap delegation (R5); no self-PATCH of modules; an active member's re-invite applies the new assignment. [EA; HIGH]
- **T15 Scoped service credentials (R7):** one Tenant per credential (D5), explicit endpoint allow-list per credential (GL first: the other services need a small route subset), distinct client and audience per recipient (SOP: GL vs EA owner-contact), GL validates the Tenant header against the credential and the Company's real Tenant; then POP/IM/SOP/HR derive the Tenant from the Company instead of a deploy-time value. Decide GL's options A/B inside this task. Ahead of Epic 13's ER→SOP inbox. [GL, EA, CM for secrets/Terraform; HIGH]
- **T16 WEB:** gate by capability (R11), display the self-approval flag, remove READ-floor assumptions, stop sending `approvedBy`/`confirmedBy` (T8). [WEB]
- **T24 Platform operator capability for reference data** (R14). [GL]

**Audit and runtimes**
- **T17 Shared minimum audit record** shape (R10), owned by EA, adopted by each service's T22 writer. [EA]
- **T18 Runtime extension contract (R12)** published; the Education Runtime's RBAC SPUTO follows it; ER student read gets a per-child guardian check. [ER, CM]

---

## 5. Order (foundations first)

1. **Now (already authorised):** T1, T19, T20, T21, plus T4 for SOP: they only add refusals. T23 (production data check) and the Femi decision batch (D5, D7-D11).
2. **Femi decides D5 and D7-D11** (this document is the agenda). CM then writes T5 as the settled definitions.
3. **Foundations that need no decision but need CM's go:** T2/T3, then T22 (acting identity) service by service, starting with POP (T9a) and SOP.
4. **Capability model:** T5a is a platform-wide contract change and **blocks everything in the "separation of duties" group**; consumers declare the field first, migration maps legacy levels to full sets (B1) so nothing changes for anyone on day one. T6/T7 follow, with T7 after the production check.
5. **Separation of duties and limits:** T8-T13 in risk order: SOP (F2), POP (F3), HR, IM, ER (F4, F11), GL.
6. **Delegation and service scope:** T14, T15 (before Epic 13's ER→SOP inbox), T16, T24.
7. **Audit and runtimes:** T17, T18, then each runtime's own RBAC SPUTO.
8. **Application round with every peer (Femi's instruction):** statements are in; next CM meets each peer to settle its row below. No service changes its model beyond the authorised items before its row says "agreed".

### Status table

| Service | Statement | Findings affecting it | Authorised now | Agreed plan / branch | CM reviewed |
|---|---|---|---|---|---|
| EA | `docs/RBAC_EA_Statement.md` | F5, F7 (Owner assignments exist), F8 (operator tokens), T5a/T6/T14/T17 | none | five-deploy T5a rollout proposed | statement yes |
| GL | `docs/RBAC_GL_Statement.md` | F1, F6 (no endpoint scope), F9, F15, T12 | T1, T19 (in progress) | T12 content proposed | statement yes |
| POP | `docs/RBAC_POP_Statement.md` | F3 | T22/T9a (`pop_audit_log`, same transaction) | T9b after T5a | statement yes |
| SOP | `docs/RBAC_SOP_Statement.md` (+ section 7, B1-B10) | F1, F2/F2b, F3, F12, ER credential | T1, T4 | S-T1 = T22, T8, T7 last | statement yes |
| IM | `docs/RBAC_IM_Statement.md` | F1 (not exploitable as built), F3, F10, F13 | T20, T1 pin | T11 after T5a | statement yes |
| FA | `docs/RBAC_FA_Statement.md` | disposal/impairment approval (T12), F9 | via GL T19 | G1-G4 behind T5a | statement yes |
| HR | not yet | F3 (T10), owner match exact-case | none | | |
| ER (Education Runtime) | `docs/ER_RBAC_SPUTO.md` | F4, F8, F11, F14 (fixed), legacy assessment routes (A8) | T21, T-ER9 | D-ER1..7 to Femi | SPUTO read; review pending |
| WEB | not yet | F7 comment drift, T16 | none | | |
| Omniview | not yet | R13 | none | | |

---

*Sources: the 2026-10-08 code survey (nine checkouts), `docs/Per_Company_RBAC_Design.md` (2026-09-23; its section 3(f) said Owner-Admin-implies-ADMIN "is confirmed wrong and should not be built", which matches Femi's correction), `docs/Service_Account_Identity_And_EA_Membership_Design_Note.md` (v1.8), `docs/Service_Account_Principal_Cutover_Scope.md`, `docs/GL_Tenant_Header_Service_Account_Options.md`, the peers' statements listed above, and CM's checks of `origin/master` and the live task definitions.*
