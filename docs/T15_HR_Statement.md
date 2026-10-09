# T15: HR / Payroll statement (multi-Tenant on one deployment)

**Owner:** HR session. **Status:** statement for the T15 plan (`docs/T15_MultiTenant_SPUTO.md` v1.1), docs only, 2026-10-09. **Written against:** HR `origin/master` at the owner-check change (`/me`-based), payroll approval Waves 1 to 3 and the duplicate-period guard, all live. Every claim was read from that code. No code or authorization change is made by this document (the freeze holds until CM's plan says otherwise).

The six points CM asked for, in order, then the two walls, then the M1 slice.

---

## 1. Every place HR binds to a Tenant or a fixed Company

| Binding | What it does today | Where |
|---|---|---|
| `HR_EA_TENANT_ID` (required at start, no default) | The one Tenant HR serves. It is read once and handed to: (a) `HrMembershipAuthorizer`, which takes **only the `/me` Membership block of that Tenant** (`memberships.firstOrNull { it.tenantId == tenantId }`), so a person of any other Tenant gets `NO_MEMBERSHIP` at every Company; (b) `requireOwnerCaller` (the `/me`-based Owner check) for payroll approve, reject and retry, expense and salary-advance approve and reject, the expense policy, and a pay or bank change; (c) every EA proxy path `/api/tenants/{tenantId}/memberships...` (invite, list, remove, module update). | `Application.kt` (`eaTenantId`), `Auth.kt`, `OwnerCheck.kt`, `ktor_ea_gateway.kt` |
| `HR_GL_ENGINE_TENANT_ID` (required at start, no default) | Fixed into `KtorGlEngineGateway`; sent as `X-Tenant-Id` on **every** GL call (six endpoints, listed in section 4). | `ktor_gl_engine_gateway.kt` |
| HR's service identity | One Cognito client credential for all GL calls (`glBearerTokenProvider`). Under EA's model it is one User with a Membership in the first Tenant. | `Application.kt`, `cognito_service_account_token_provider.kt` |
| Fixed Company | **None.** Every Company comes from the path, the query or the body, or from the record being acted on. (An old comment in `Application.kt` still says HR "has no single fixed company": that is true and stays true.) | routes |
| Startup singletons | One JWT verifier (`HR_JWT_ISSUER`, `_AUDIENCE`, `_JWKS_URL`: identity, not Tenant), one authorizer, repositories that take no Tenant. **One bank-details encryption key for all rows** (`HR_BANK_DETAILS_ENCRYPTION_KEY`). | `Application.kt`, `field_cipher.kt` |

The two Tenant variables are the whole of the single-Tenant assumption in HR's configuration. **The bank-details key is a finding of its own:** in a shared deployment, one key encrypts every Tenant's bank details. It is not a read path across Tenants (rows are reached by Company), but a key compromise or a future code path that decrypts the wrong row would cross the wall. Per-Tenant data keys are the proper answer; see section 6 (decision for CM).

---

## 2. Routes not scoped by a Company in the path, and what they return

HR has no route that lists across Companies. What varies is **how the Company is learned**:

| Route family | How the Company is found | Authorization today | Multi-Tenant status |
|---|---|---|---|
| `GET /companies/{companyId}/...` (employees, payroll submissions, expense-claim policy, module responsibilities) | path | `authorizeHr*(companyId)` | Safe once the authorizer reads the block that **contains** the Company (R1). |
| `POST /employees`, `POST /payroll/run` | body `companyId` | `authorizeHrForWrite(companyId)` | Same. |
| `GET /payroll/last-run?companyId=` | query | `authorizeHrForRead(companyId)` | Same. |
| By id: employees, leave requests and balance, expense claims, salary advances (create/list per employee), payroll submissions, preview | the **record's own Company**, loaded first, then authorized, with an unauthorized record answered **404** (not a 403), so existence is not leaked | `authorizeHr*(record.companyId, notFoundAs)` | Safe under R1. Needs the isolation tests (section 5). |
| By id, **Owner-only**: payroll approve, reject, retry; expense-claim approve and reject; salary-advance approve and reject | the record's Company, loaded, **then only "is the caller the Owner of the configured Tenant"** | `requireOwnerCaller(configured Tenant)`; **no Company check, no 404** | **Must change** (finding F-HR-1 below): it must become "the caller is the Owner of the Tenant whose Companies contain this record's Company". |
| `PUT /companies/{companyId}/expense-claim-policy` | path | Owner of the configured Tenant; no Company check | Same fix as above. |
| `PUT /employees/{id}` pay or bank change | the record's Company | module gate on the record's Company, then the Owner check | Same fix. |
| `/team` (invite, list, remove) | **none**: Tenant-wide in EA | HR adds no check; forwards the caller's token to EA with the **configured** Tenant | Needs an explicit Tenant (finding F-HR-4). |
| `GET /companies/{id}/employees/module-responsibilities`, `PUT /employees/{id}/module-responsibilities` | the Company (path, or the employee's) | forwards to EA with the configured Tenant | Same as `/team`. |
| `/health` | none | none | Fine. |

Unknown Company or Tenant today: a Company absent from the caller's `/me` is NONE for everyone, so the gate answers 403 (or 404 on by-id routes). That is already deny-by-default; there is no fallback to look for, except the configured Tenant in the places above.

### Findings

- **F-HR-1 (HIGH, becomes exploitable with a second Tenant): the Owner-only routes never relate the Owner to the record's Company.** Today the Owner check says "Owner of the Tenant in `HR_EA_TENANT_ID`", which is correct only because every row in HR's database belongs to that one Tenant. With two Tenants in one database, the Owner of Tenant B fails the check on a Tenant A record only by accident of the configured variable; once the variable goes, the check must be tied to the record. Fix: find the caller's `/me` block whose `companies[]` contains the record's Company; require `isOwnerAdmin` in that block; no match is 404.
- **F-HR-2 (HIGH, exists today across Companies): a payroll run does not check that each line's employee belongs to the run's Company.** `SubmitPayrollRunUseCase` and `PayrollBatchBuilder` look an employee up by id and never compare `employee.companyId` with the run's. So a person with WRITE at Company B (same Owner, or in a second Tenant, anyone who learns an employee UUID from Company A) can submit a run for Company B containing Company A's employee: the run records A's employee **name** on the line (returned in B's responses), computes A's pay and leave, and later posts to B's GL. This is a wall-2 hole (Company vs Company) now and a wall-1 hole later. It needs a one-line rule in the submit use case and in the builder (employee must belong to the run's Company, else `employee_not_found`, the same answer as a missing id so it is not an oracle). **I propose to ship this first, on its own, as an add-a-deny.**
- **F-HR-3 (MEDIUM): approve bodies carry GL ids.** Expense-claim and salary-advance approve take the GL period and account ids from the request body and pass them to GL. HR does not check they belong to the record's Company; that relies on GL's own period and account check (GL T19). I depend on GL here and will not add a second source of truth, but the isolation suite will include a cross-Company id case so a GL regression is caught.
- **F-HR-4 (MEDIUM): `/team` and module-responsibilities have no Tenant in the request.** In a shared deployment a person with Memberships in two Tenants must say which one they mean; HR must validate it against the caller's `/me` blocks, never take it from the body unchecked.

---

## 3. Tables without a Company key, and queries not filtered by one

| Table | Company key | Reached how |
|---|---|---|
| `employees` | `company_id` (indexed) | `findAllByCompany`; by id then authorized |
| `payroll_run_submissions` | `company_id` (indexed) | `findAllByCompany`; by id then authorized |
| `payroll_run_history` | `company_id`, with pay frequency (indexed) | by Company and frequency |
| `expense_claim_policies` | `company_id` (primary key) | by Company |
| `leave_requests`, `expense_claims`, `salary_advances` | **none**: `employee_id` only | via the employee, so the Company is the employee's |
| `payroll_run_submission_lines`, `payroll_run_submission_postings` | none: `submission_id` | via the submission |
| `employee_change_audit` | none: `employee_id` | via the employee |

No table carries a Tenant id, and none needs one for isolation **provided Company ids are globally unique and a Company belongs to exactly one Tenant** (EA's index, to be confirmed in production per the plan's E1). The Company is the key and the Tenant is derived from the caller's `/me`.

Queries: every list is filtered by Company. The by-id finders (`findById`) are not, by design; their safety is the **load, then authorize against the record's own Company, answer 404** pattern, which is a code-review rule, not a database guarantee. That is the same finding the RLS note recorded, and I am not proposing a schema change for it now.

Recommended additive hardening (not on the M1 critical path): a `company_id` column on `leave_requests`, `expense_claims` and `salary_advances` (copied from the employee, with a foreign-key check that it equals the employee's), so these three lists and finders can be filtered in the query itself, as the plan's R4 asks for the tables reached only through a parent. Estimate in section 6. The advisory lock key for the duplicate-period guard already includes the Company, so concurrent runs of different Companies or Tenants never block each other.

---

## 4. Every outbound call, and how Tenant and Company would be passed per request

| Call | Today | Per request in a multi-Tenant world |
|---|---|---|
| EA `GET /me` (the module gate, the Owner check, bank-detail visibility) | the caller's own token; no Tenant parameter | unchanged. Tenant-agnostic by nature: the response carries every Tenant the person belongs to, and each block lists its Companies. |
| EA `GET/POST/DELETE /api/tenants/{tenantId}/memberships...` and `PATCH .../modules` (the `/team` and module-responsibilities routes) | configured Tenant in the path | Tenant from the request, validated against the caller's `/me` blocks (F-HR-4). If the caller has exactly one block the route may default to it; if more than one, WEB must send it. |
| GL `GET /companies/{id}/payroll-posting-context`, `POST /payroll/record-pay-run`, `POST /leave-accruals` (+ `/{id}/utilize`, `/{id}/remeasure`), `POST /journal-entries` (expense claims, salary advances and advance recoveries) | HR's service credential with `X-Tenant-Id` fixed to the configured value | Under the plan's **option A** the service credential may **omit** `X-Tenant-Id` and GL derives and verifies the Tenant from its own Company record, so HR sends no Tenant at all and keeps the Company in the path or body as today. That also removes the problem of "which Tenant does a *resumed* payroll run use", because it is never HR's to know. |

Confirmation for CM's allow-list question: those are the six GL calls HR makes, exactly the list CM gave: `GET /companies/{id}/payroll-posting-context`, `POST /journal-entries`, `POST /leave-accruals`, `POST /leave-accruals/{id}/utilize`, `POST /leave-accruals/{id}/remeasure`, `POST /payroll/record-pay-run`. Expense claims and salary advances use `POST /journal-entries`; payroll retries and resumes reuse the same endpoints. **HR never calls `POST /tenants/{id}/companies`.**

For EA's question: **every HR flow that reaches GL starts from a signed-in person.** Payroll approve, resume and retry are the Owner's request; leave approval is an APPROVE-level person's; expense and advance approval are the Owner's. HR runs no scheduler and has no inbound service login, so there is no flow that must learn a Tenant from a Company without a person. **The planned EA Company-to-Tenant lookup is not needed by HR.** Where HR needs the Tenant (the Owner check, the module gate, `/team`) it takes it from the caller's `/me`.

---

## 5. Tests that prove isolation (both walls)

R5: table-driven over every route and parameterised "same Tenant" and "different Tenant", so a new route cannot pass one wall and skip the other. A two-Tenant fixture: Tenant A (Owner OA; Companies A1, A2; a delegate DA1 with HR at A1 only) and Tenant B (Owner OB; Company B1). Each Company has an employee, a leave request, an expense claim, a salary advance, a PENDING and an APPROVED payroll run.

**Wall 1: Tenant vs Tenant.** For OB and a B1 delegate, on every route of section 2: list A1's employees, payroll runs, leave, expenses, advances (403/404, never A's rows); GET, PUT, preview, approve, reject, retry by **A1's record id** (404, the same body as a random UUID, so there is no oracle); POST into A1 by body (403); submit a B1 payroll run containing **A1's employee id** (rejected as not found; A1's name never appears in any B1 response); expense policy PUT for A1 by OB (404/403); `/team` and module-responsibilities return only the caller's own Tenant and refuse a Tenant the caller is not in. Outbound: capture the GL calls of an A1 approval and a B1 approval: none carries the other Tenant's id; and with `HR_*_TENANT_ID` unset, HR still starts and an unknown Company is refused. Plus the **first-Tenant regression**: Tenant `9fa2198b-...`'s existing data and behaviour are unchanged with a second Tenant present.

**Wall 2: Company vs Company inside one Tenant.** OA holds A1 and A2. A1's employees, payroll runs, leave, expenses and advances **never appear in A2's lists**. A call with A2 in the path or body and an A1 record id (for example a payroll run for A2 whose line names an A1 employee; leave or advance by an A1 employee id on an A2-scoped route) is 404/403. DA1 (HR at A1 only) gets 404 for every A2 record by id and an empty A2 list. The duplicate-period guard is per Company (A1's March run does not block A2's).

**Database level (real Postgres):** every repository finder by Company returns only that Company's rows with two Companies of two Tenants seeded; a leave, expense or advance row cannot be attached to an employee of another Company (once the recommended `company_id` check exists).

**Guessing:** a random UUID and a real record the caller may not see return identical responses (status and body).

---

## 6. Estimate and order inside HR

Order is by risk and dependency. Days are working days including tests, in my own checkout, handed to CM as branch and tip.

| Slice | What | Estimate | Depends on |
|---|---|---|---|
| **H0: ship now, add-a-deny** | F-HR-2: an employee must belong to the run's Company (submit, builder, preview), same 404-style answer as a missing employee; wall-2 tests for it | 0.5 d | nothing (closes a hole that exists today) |
| **H1: authorizer per request (R1)** | `HrMembershipAuthorizer` and the Owner check read the `/me` block whose `companies[]` **contains** the Company in the request; exactly one match, else 403/404; Owner-only by-id routes find the record's Company first and answer 404 when the caller has no block for it (F-HR-1); expense policy PUT likewise; remove the configured-Tenant parameter from both | 2 d | none beyond EA's `/me` carrying all Companies for an Owner and only assigned ones for staff (EA's statement confirms) |
| **H2: GL without a Tenant** | stop sending the configured `X-Tenant-Id` on the service path (option A), keep it if GL's G4 is not yet live; drop `HR_GL_ENGINE_TENANT_ID` | 0.5 d | GL G4 released |
| **H3: `/team` and module responsibilities** | Tenant from the request, validated against the caller's blocks (F-HR-4) | 1 d (+ WEB to send the Tenant for people in several) | WEB, EA |
| **H4: the isolation suite (section 5)** | table-driven, both walls, real-Postgres finder tests, first-Tenant regression | 3 d, written alongside H1 to H3, not after | the two-Tenant fixture |
| **H5: remove `HR_EA_TENANT_ID`** (M3, R6) | delete the env var and its fallback; start-up no longer needs it | 0.25 d + CM's Terraform | after H1 and H3 have run in production |
| **H6 (not on M1): company key on leave, expense, advance tables** | additive `company_id` + check; finders filter in the query | 1.5 d | none |
| **H7 (decision): per-Tenant bank-details key** | one key per Tenant (key id on the row, keys in Secrets Manager) | 2 to 3 d | CM's call on whether it is needed before the second paying Tenant |

**M1 slice for HR (CM's question): H0 + H1 + H2 + H4 (the suite for them), about 6 working days, in this order, each its own branch from `origin/master` and its own review.** H3 follows (the second customer's Owner needs to invite staff, so I would not leave it long). H5, H6, H7 are after M1.

**Acceptance for M1 in HR:** the section 5 suites pass, a second Tenant's Owner can create employees, submit, preview, approve and retry payroll for his own Company, and nothing of the first Tenant's is visible or reachable by him, by list, by id or by guess.

---

## 7. What HR needs from others

- **EA:** confirm `/me` lists, for an Owner, every Company of the Tenant, and for staff only their assigned Companies, in the same response shape (EA's statement says so); a Company in at most one Tenant (E1 index check in production); the shape of the Tenant argument WEB will send for people in several Tenants.
- **GL:** G4 (service credentials may omit the Tenant header) released before H2; the allow-list confirmed against the six calls above.
- **WEB:** send the Tenant on `/team` for a person in several; no other HR contract changes.
- **CM:** decision on H7, and the Terraform change to remove the two environment variables at M3.
