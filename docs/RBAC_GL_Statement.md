# RBAC: GL statement (application round)

**Owner:** the GL session. **Status:** draft, 2026-10-08, docs only. **Answers:** `docs/RBAC_SPUTO.md` v0.2 (CM), section 5, step 6. **No code or authorization-model change is proposed to start**: the freeze stands, and the tasks below are proposals for CM to confirm. Everything about GL was read from GL `origin/master` `b4723da` (deployed `:98`) on 2026-10-08; file references are relative to `GL/src/main/kotlin/com/theprodeogroup/fish/`.

---

## 1. GL's current authorization rules, as the code does them

**Identity.** Every route sits inside `fishAuthenticated` (`infrastructure/web/Auth.kt:302`), which accepts the human Cognito provider plus four service providers (SOP on the unsuffixed audience, IM, HR, POP). A token is accepted if it verifies and carries an `email` claim (`Auth.kt:183-185`); nothing else is read from it. Exceptions with no authorization beyond a valid token: `GET /me`, `GET /jurisdictions`; `GET /health` needs no token at all.

**The order of checks on a Company route.** (1) `resolveTenantForCompany` derives the owning Tenant from the Company in the path or body (404 `not_found` if the Company does not exist; `Auth.kt:527`). (2) `verifyClaimedTenant` requires an `X-Tenant-Id` header and compares it with that Tenant (400 if missing, 403 "X-Tenant-Id does not own the requested resource" if different; `Auth.kt:548`). (3) One of the `authorizeTenantFor*` functions (below). The Tenant is therefore always derived from the Company; the header is a second, caller-stated assertion that must agree.

**People.** `authorizeTenant` (`Auth.kt:347`) asks EA `GET /me` with the caller's own token. EA unreachable = 503 (fail closed); no Membership in the Tenant = 403; then the **access level at that Company** must be at least the route's floor (`membership.accessLevelAt(companyId).atLeast(min)`; levels are compared by ordinal NONE < READ < WRITE < APPROVE < ADMIN); then, only if the route names a module, that module must be in the grants at that Company. The floors in use are **READ and WRITE only**: `authorizeTenantForAdmin` (ADMIN, `Auth.kt:423`) has no callers, and **APPROVE is never used anywhere in GL**.

**Owner-Admin special cases (three, all in EA-facing code).** (a) `accessLevelAt` returns READ for the Owner-Admin when EA reports no explicit level at a Company (`infrastructure/ea/ea_membership_gateway.kt:80-82`), whether the Company is absent from `/me` or present without a level; everyone else gets NONE. That floor carries **no modules** (`grantedModulesAt`, `:86`). (b) `authorizeTenantOwnerAdmin` (`Auth.kt:475`) lets only the Owner-Admin add a Company to the Tenant (`POST /tenants/{tenantId}/companies`), the one Tenant-wide gate. (c) Nothing else is owner-specific; GL applies no write uplift.

**What each route needs** (verified route by route):

| Gate | Routes |
|---|---|
| none beyond a token | `GET /me`, `GET /jurisdictions` (any signed-in caller, no Tenant needed) |
| READ at the Company | all reports (balance sheet, profit and loss, trading profit and loss, cash flow, working capital, fixed-asset register), money and expense velocity, sales-to-expense ratio, accounts, journal-entries list, customers, sales-invoices, fixed-assets list, bank-reconciliations (list and read), `vat-categories`, the four posting-context reads, and the aging and balance reads (they are POSTs with a body but only read) |
| WRITE at the Company | `POST /journal-entries` (a generic balanced entry, created and posted in one call: `application/PostJournalEntryUseCase.kt:102-103`), `POST /companies/{id}/accounts` (create an account), `PUT .../accounts/{id}/expense-classification` (re-tag), `POST .../accounts/{id}/opening-balance`, all four opening-import routes **including the two `/validate` dry runs**, all fixed-asset actions (create, depreciate, impair, **dispose**), bank-reconciliation start, match and unmatch, `create-invoice`, the integration postings (`record-sale`, `record-collection`, `record-sales-return`, `record-obligation`, `record-payment`, `record-receipt`, `record-issue`, `record-pay-run`) and the leave-accrual actions |
| TAX module with WRITE or READ | `GET` and `POST /companies/{id}/tax`, `POST .../vat-return` (the only routes that check a module grant at all) |
| Owner-Admin | `POST /tenants/{id}/companies` |

**Service callers.** A token from one of the four service providers is marked `isServiceAccount` (`Auth.kt:131-163`), and `authorizeTenant` returns immediately for it (`Auth.kt:358`, `:481`): **EA is never consulted, and no access level, module or route restriction applies.** The only per-request check left is the header comparison in step (2). Nothing ties a service token to a Tenant, a Company or an endpoint set: the provider names appear only in `Auth.kt`, so any of the four credentials may call **every** route, including `POST /journal-entries`, account creation, re-tagging, opening balances and imports. The Education Runtime posts through SOP, not GL directly.

**Approvals, audit, periods.** GL has **no approval step on any route**: a WRITE caller creates and posts in one call, and the creator is the only person involved. The domain already has `DRAFT`, `PENDING` and `REJECTED` posting statuses (`domain/common/posting_status.kt`), but nothing uses them for a workflow. No actor is stored on a journal entry (only `source`: manual, integration, reversal, and the service-account entry's description); the audit-trail store exists and has no writers (`GL/docs/GL_Audit_Trail_Backlog.md`, Wave 2 not built). **There is no route to create, open or close a Period**, so the ADMIN gate would have nothing to guard there yet; and the reversal use case exists with no route. Reference data (jurisdictions, `vat_rates`, the Tenant-independent flags) is changed by data updates run by CM and Femi, not through any role.

---

## 2. Survey findings re-verified against GL master

| Finding | Verdict | Evidence |
|---|---|---|
| F1 fail-open service verifiers | **CONFIRMED** (latent) | `infrastructure/web/Application.kt:498` `serviceVerifier ?: verifier` (and the three siblings on that line); in `installFishJwtAuth` every service verifier also **defaults** to the human `verifier` (`Auth.kt:110`, `:117`, `:121`, `:124`). CM's live check (all four audiences set) agrees with mine from the earlier read. A service-audience variable unset after a redeploy would register a human token as a service account. |
| F3 (GL part): money created and approved by the same person | **CONFIRMED** | There is no approval concept: `POST /journal-entries` creates and posts (`PostJournalEntryUseCase.kt:102-103`); disposals, opening balances and imports are WRITE; no actor is recorded. |
| F6 service tokens are blanket | **CONFIRMED, and wider in GL than the survey says** | Not only not Tenant-bound: not **endpoint**-bound. Any service credential can call the generic journal, account creation, opening balances and imports, none of which SOP, POP, IM or HR needs. The survey's "GL derives the Tenant from the Company" is **PARTLY** right: GL derives the owning Tenant but still requires the caller to state it in `X-Tenant-Id` and compares them (`Auth.kt:548`). |
| F7 Owner-Admin / Company-missing fall-back (GL returns READ) | **CONFIRMED** | `ea_membership_gateway.kt:80-82`; deliberate since 2026-09-28 (a bug fix for an Owner-Admin 403 when EA omitted a Company from `/me`). |
| "GL's ADMIN gate is unused" | **CONFIRMED** | `authorizeTenantForAdmin` (`Auth.kt:423`) has no callers (grep). |
| Module grants | **CONFIRMED, not in the survey list** | Only the TAX routes check a module. The `GL` grant is never enforced: a person with WRITE at a Company and no GL module can post (documented in `Auth.kt:439`'s comment as a known gap). |

---

## 3. Gaps against R1 to R13 and the tasks that touch GL

| Req | GL gap | Task | GL estimate (one person, with tests, no dates) |
|---|---|---|---|
| R6 fail closed | F1 above | **T1** | Small to medium (about a day): remove the `?: verifier` fall-backs and the `= verifier` defaults, refuse to start when a service audience is unset. The cost is the roughly 25 test fixtures that rely on the defaults (they need an explicit test verifier). |
| R8 consistent fall-backs | GL gives the Owner-Admin READ for an absent Company | **T4** | Small (half a day), **but see objection 1: it must follow T6.** |
| R1 / D1 capability set | GL compares ordinal levels (`atLeast`); ADMIN currently implies APPROVE and WRITE | **T5a (consumer side)** | Medium (about two days): declare the new field strictly, replace the ordinal gates at about 50 call sites (read, write, approve, administer), tests. Consumers-first, as CM states. |
| R2 approvals | None in GL | **T12** | See section 3.1. |
| R3 thresholds and policy | GL has none yet (no manual-journal limit) | T12 | with T12 |
| R7 scoped service credentials | F6 above, plus the header | **T15** | Medium (two to three days) after D5; see section 3.2. |
| R10 audit | The store exists with no writers; no actor on entries; re-tagging, VAT and exempt-only changes unaudited | **T17** | Large: the GL Audit Trail Wave 2 (same-transaction, fail-closed writes across about 30 use cases, already designed in `GL/docs/GL_Audit_Trail_Software_Requirements_Specification.md`). The pre-Live audit rows in `docs/GL_POP_IM_SOP_Backlog.md` (re-tag, VAT rows) belong here. |
| R1 (module grants "within granted modules") | The GL module grant is not enforced | new (see objection 4) | Small once T6 exists |
| R9 canonical email | GL passes the token's email to EA unchanged; matching is EA's | T2 (EA) | none in GL |
| R4, T6, T7, T14, T16, T18 | Not GL | | GL has no uplift to remove (that is SOP's) |

### 3.1 What GL proposes T12 should contain (to be confirmed, not started)

- **ADMIN guards configuration, never posting** (D1): creating or recoding accounts, re-tagging expense accounts (it moves gross margin), account packs and the account-role mapping when built (the Epic 13 proposal), and **period management** when it exists (opening a period, closing one, setting the calendar). Today account creation and re-tagging are WRITE and should move to ADMIN.
- **APPROVE guards decisions that move or hide money**, with creator not equal to approver for employees and the Owner's self-approval flagged (D6): (1) **manual journals above a limit** (the limit itself ADMIN-set); the domain already has `DRAFT` and `PENDING` statuses, so the shape is create as draft, approve to post; (2) **fixed-asset disposal and impairment**; (3) **opening balances and opening imports** (one-off, equity-affecting; the `/validate` dry runs should drop to READ); (4) **reversals** when the route is exposed; (5) **period close** when it exists. Integration postings from SOP, POP, IM and HR (`source` = integration) are **not** re-approved in GL: their approval lives in the source service (P3 applied there), and GL records the service principal plus a document reference.
- **WRITE keeps** the operational postings a bookkeeper does (bank reconciliation, depreciation, leave accrual actions, draft journals).

### 3.2 The Tenant header and service credentials (F6, R7, T15)

The two options are written out in `docs/GL_Tenant_Header_Service_Account_Options.md`. In short: **A** lets service accounts omit `X-Tenant-Id` (GL derives and verifies the Tenant), **B** adds a Company-to-Tenant read route. IM prefers A; neither is safe without a **scope on the credential**. If D5 is "one Tenant per credential" (CM's recommendation), GL's side is: a per-credential binding in configuration (credential audience to the Tenant, or set of Tenants, it may act for), enforced in `verifyClaimedTenant` and in the Company-to-Tenant resolution: a service call is refused unless the **Company's own Tenant** is in the credential's scope, whether or not a header is sent. With that in place **A becomes safe and B unnecessary**: callers can drop their deploy-time Tenant. GL would fail to start if a service credential has no declared scope (P4). The same binding should carry an **endpoint allow-list** (the larger gap, section 2 F6): SOP the sales and receivable routes and their reads; POP the purchasing routes and reads; IM the inventory routes and its posting context; HR the payroll and leave routes; none of them the generic journal, account creation, re-tagging, opening balances or imports. GL can derive the first list from its own route inventory; each service must confirm its list (section 5).

---

## 4. Objections, corrections and things the SPUTO misses

1. **T4 must follow T6, not precede it.** Making an absent Company NONE for the Owner-Admin re-creates the bug fixed on 2026-09-28 (a real Owner-Admin got 403 on `sales-invoices` because EA omitted a Company from `/me`). It is only safe once EA reports the Owner's **explicit assignments** at every Company (T6/R4), after which GL's local READ floor can be deleted rather than "made consistent". Order: T6, then T4.
2. **R2's "approver identity from the token" does not fit integration postings.** A service token carries only the service's email; the human approver is known to the source service. GL should store the source service principal and a document reference (the source's invoice or receipt number, already put in the description) and rely on the source service for the human approval (P9 at the source). A shared "acting user" header would be unverifiable and should not be added without the SPUTO deciding how a service attests to a person.
3. **Endpoint scoping of service credentials (section 3.2) is the cheapest, highest-value control in GL and R7 should say it explicitly**, not only Tenant scope: a leaked or misused IM credential today can post arbitrary journals to any business whose Tenant header it supplies.
4. **The GL module grant is not enforced anywhere** (only TAX), although R1 defines READ as "within granted modules". Enforcing it is a small change but it **conflicts with the Owner-Admin's READ floor, which carries no modules**: it must wait for T6 (explicit owner assignments) or every Owner-Admin loses the GL reads. Order: T6, then module enforcement.
5. **Reference data has no role.** Jurisdictions, `vat_rates` (including the `verified` flag) and the exempt-only flag proposed for Epic 13 are platform data changed by CM running SQL that Femi executes. They are not tenant roles, and R13 (operators) does not cover them. The SPUTO should name a **platform-operator capability for reference data** with its own audit, because a wrong tax rate or a verified flag posts to every tenant's books.
6. **D6 "Owner self-approval flagged" needs an audit field GL does not have** (an actor and a self-approval flag on the entry). It is T17's first deliverable for GL, not an add-on.
7. **Idempotency keys are scoped per Tenant and endpoint, not per caller**: any caller in the Tenant who knows a key can replay its stored response. Low risk, noted for R10 and R7.
8. **`/validate` routes require WRITE** (they only dry-run). Under R1 they should be READ; trivial, but a visible example of "WRITE used where READ would do".

---

## 5. What GL needs from others

- **EA:** the capability-set shape for `/me` (T5a: field names and migration of existing assignments); the explicit Owner assignments at every Company (T6) before GL touches T4 or enforces the GL module; and the D5 mechanism (where a service principal's Tenant scope lives: a Cognito resource scope per credential, or configuration in GL).
- **SOP, POP, IM, HR:** confirmation of the exact GL routes each credential needs, from the list in section 3.2 (so the allow-list is right the first time), and that each can live with the endpoint restriction. IM's Phase 1 (post to the item's own Company) already assumes the Tenant stays configured until the SPUTO settles D5.
- **WEB:** the manual-journal approval flow (a draft or pending state, an approver's list, and creator not equal to approver messaging) and the ADMIN-only configuration screens (accounts, re-tagging, later periods) when T12 is confirmed. GL supplies the routes.
- **CM:** release order across GL and its consumers for T1, T5a and T15 (consumers declare first); Terraform and secrets for per-credential scope configuration; and a ruling on who owns **reference-data changes** (objection 5).
- **Femi:** D5 (service credential scope), and for GL specifically the **manual-journal limit** (a number, per Company or global) and which postings count as "above a limit".

---

## 6. Proposed order for GL's part (all subject to the freeze)

1. **T1** (fail closed), independent of every decision: first.
2. **T5a (consumer side)** with EA's capability set; **T6** (EA) before any change that depends on the Owner's explicit assignments.
3. **T4** and **GL-module enforcement**, after T6.
4. **T15** (scoped credentials plus the endpoint allow-list), after D5.
5. **T12** (ADMIN on configuration; approvals for manual journals above the limit, disposals, opening balances and imports; period management as its own SPUTO first).
6. **T17** (audit writers), starting with the actor and self-approval flag on entries, then Wave 2 of the audit trail, folding in the re-tag and VAT-row audit rows.
