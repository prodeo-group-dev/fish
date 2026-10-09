# T15: how GL scopes by Tenant and Company today (GL statement)

**Status: 2026-10-09. Statement only; nothing changed.** Written by the GL session at CM's request, in the frame used for POP, IM, HR and SOP. Everything below was read from GL master `7dc8e12` (routes, `Auth.kt`, migrations V1 to V31, repositories, tests), not recalled. Where I could not check something from the code (anything in a task definition or another service), I say so. Femi's ruling is **multi-Tenant first**; the context is `docs/RBAC_SPUTO.md` (T15, D5, P7), `docs/RBAC_GL_Statement.md` section 3.2 and `docs/GL_Tenant_Header_Service_Account_Options.md`.

## 0. The short version

- **GL is already multi-Tenant for people.** A person's access is decided by the **Tenant that owns the Company the request names**, looked up through EA's `/me` (`memberships.firstOrNull { it.tenantId == tenantId }`), never by "the caller's" Tenant. Nothing in GL assumes one Tenant per user or per deployment.
- **GL holds no Tenant or Company id in its own configuration.** It reads 16 environment variables; none is a Tenant or Company id. The single-Tenant coupling in the platform is in the **callers** (SOP, POP, IM and HR send a deploy-time `X-Tenant-Id`), not in GL.
- **GL's gap is service credentials.** A valid service token (SOP, POP, IM, HR) skips the membership check completely, and nothing in GL limits which Tenants or which endpoints a credential may use. The `X-Tenant-Id` header is the **only** per-request Tenant assertion, and it is checked against the Company's own Tenant, so it catches mistakes, not misuse.
- **Two findings that deny-by-default should fix first** (section 1.5): a service verifier that falls back to the human verifier when its audience variable is unset, and `POST /tenants/{tenantId}/companies` accepting any service credential for any Tenant id.
- **Estimate: about 4 to 5 working days in GL**, ordered in section 6; the part that needs Femi's D5 decision is about 2 to 3 of them.

## 1. Where GL binds to a Tenant or a fixed Company

### 1.1 The per-request rule (every Company route)

Every route that touches a Company's data does the same four things, in order (`Auth.kt`):

1. `resolveTenantForCompany(companyId)`: loads the Company, answers 404 if it does not exist, and returns **the Company's own `tenant_id`**. This is the only place GL learns a Tenant.
2. `verifyClaimedTenant(tenantId)`: requires an `X-Tenant-Id` header (400 if absent) equal to that Tenant (403 `X-Tenant-Id does not own the requested resource` if not).
3. `authorizeTenantFor{Read,Write,Admin,Module}(tenantId, companyId)` for a **person**: asks EA (`GET /me`) for the person's memberships, finds the one for that Tenant (403 if none) and checks the access level and, for TAX only, the module grant **at that Company** (per-Company RBAC, 2026-09-23). If EA is unreachable it answers 503 (fail closed).
4. For a **service account**: step 3 is skipped (`caller.isServiceAccount` returns an `AuthorizedCaller` straight away). This is deliberate and recorded in `docs/Service_Account_Identity_And_EA_Membership_Design_Note.md`.

An audit of all route files found the full sequence on every Company route. `POST /journal-entries` carries an inline copy of the header check (same logic, a different error text); `OpeningImportRoutes` has four routes behind two shared handlers that do the full sequence. The exceptions are in 1.4.

### 1.2 Fixed Companies and Tenants in GL: none

- No Tenant or Company id is read from the environment or code. The variables GL reads are `EA_API_BASE_URL`, `FISH_CORS_ALLOWED_ORIGIN`, `FISH_DB_*`, `FISH_HTTP_PORT`, and the JWT group (`FISH_JWT_ISSUER`, `_AUDIENCE`, `_JWKS_URL`, and one `FISH_JWT_SERVICE_AUDIENCE[_IM|_HR|_POP]` per service).
- GL's own copies of the Tenancy tables (`tenants`, `users`, `memberships`, `tenant_companies`, `tenant_admin_memberships`, `membership_module_grants`) were **dropped** (V23, 2026-09). A Tenant exists only in EA; GL knows it only as `companies.tenant_id` and `idempotency_keys.tenant_id`, neither with a foreign key (V21, V22).

### 1.3 Shared reference data versus per-Tenant data

| Table | Scope | Notes |
|---|---|---|
| `jurisdictions` (V29) | **Global reference data** | Read by `GET /jurisdictions` for any authenticated caller. Changed by SQL run by CM/Femi. |
| `tax_rules` (V5, V9, seeded V31) | **Global reference data** | One rule per `(jurisdiction, tax_type)`. Same for every Company in a jurisdiction by design (`TaxRule`'s own KDoc). A wrong rate affects every Tenant. |
| `vat_rates` (V30) | **Global reference data** | With a `verified` gate. Same point: a wrong or wrongly verified rate posts to every Tenant's books. |
| `schema_baseline`, Flyway history | Infrastructure | |
| `companies` | **Per-Tenant**, key `tenant_id` | The one place a Tenant is stored. |
| `idempotency_keys` | **Per-Tenant**, key `tenant_id` | Unique on `(tenant_id, endpoint, key)`; scoped by Tenant, not by caller (so any caller in that Tenant who knows a key can replay its stored response; low risk, noted in `RBAC_GL_Statement.md`). |
| `accounts`, `periods`, `fixed_assets`, `leave_accruals`, `customers`, `creditors`, `pay_runs`, `tax_computations`, `vat_returns`, `sales_invoice_records`, `stock_shortage_escalations`, `opening_import_batches`, `audit_log_entries`, `bank_reconciliations`, `company_module_management_preferences`, `stock_items`, `purchase_orders`, `sales_orders` | **Per-Company** (carry `company_id`) | Tenant reached through the Company. |
| `journal_entries`, `journal_lines` | **Per-Company through the Period** | `journal_entries.period_id` leads to `periods.company_id`; no direct company column. |
| `purchase_order_lines`, `sales_order_lines`, `sales_order_delivered_lines`, `opening_import_row_results`, `bank_statement_lines`, `bank_reconciliation_matches` | **Per-Company through a parent row** | Child rows with no company key of their own. |

Reference data has **no role** in the RBAC model (`RBAC_GL_Statement.md` objection 5): there is no platform-operator capability, and no audit, for changing it. Out of T15's scope but it is where a cross-Tenant blast radius sits.

### 1.4 Routes that are not scoped by a Company in the path (section 2 expands)

`/health`, `/me`, `/jurisdictions`, and `POST /tenants/{tenantId}/companies`, plus 17 write routes that carry the Company in the **body** or reach it through another id (section 2).

### 1.5 Two things deny-by-default should change

**F-T15-1: a service verifier can fall back to the human verifier.** `Application.kt:509` passes `serviceVerifier ?: verifier` (and the same for IM, HR and POP). `buildJwksServiceVerifier*()` returns `null` when its `FISH_JWT_SERVICE_AUDIENCE*` variable is unset. If that happens, the "service" provider verifies **human tokens**, and `validate` marks them `isServiceAccount = true`: a human token would then skip the EA membership check. This is the same fail-open shape found in SOP (their T1). I could not check the live task definition from the code: **CM should confirm all four variables are set in production**; the code fix is to fail start-up (or reject every token) when a service audience is unset, which only adds a refusal.

**F-T15-2: `POST /tenants/{tenantId}/companies` accepts any service credential for any Tenant id.** The route calls `authorizeTenantOwnerAdmin(tenantId)`, which returns immediately for a service account; `AddCompanyToTenantUseCase` then creates the Company, and by design does not check that the Tenant exists (its KDoc: the Tenant is in EA and "the auth layer" is meant to have verified it). For a person that holds; for a service credential nothing verifies it. Today only EA/WEB-side onboarding is expected to call this, so the fix is probably "people only, Owner-Admin" (a service credential gets 403), which again only adds a refusal. Needs a quick check that no service calls it; I found no service caller in this repo's tests or docs.

## 2. Routes not scoped by a Company in the path, and what they return

| Route | How it is scoped | Returns / note |
|---|---|---|
| `GET /health` | None (public) | Liveness only. |
| `GET /jurisdictions` | Any authenticated caller, human or service | The enabled jurisdiction list: global reference data, no tenant data. |
| `GET /me` | Meant for a human token only; GL does not check `isServiceAccount` itself, it forwards the token to EA, which rejects a service token | Returns EA's answer: memberships across **all** of the caller's Tenants. |
| `POST /tenants/{tenantId}/companies` | Tenant in the path; `authorizeTenantOwnerAdmin` (people: must be Owner-Admin of that Tenant; service: bypass, see F-T15-2) | Creates a Company under the Tenant. |
| `POST /sales/record-sale`, `/sales/record-collection`, `/sales/record-sales-return`, `/sales/create-invoice`, `/purchasing/record-obligation`, `/purchasing/record-payment`, `/inventory/record-receipt`, `/inventory/record-issue`, `/payroll/record-pay-run`, `POST /fixed-assets`, `POST /leave-accruals` | `companyId` in the **body**; full four-step sequence on it | Since T19 (live), the Period named in the body must belong to that Company or the answer is the same 404 as a missing Period; accounts follow. |
| `POST /journal-entries` | Company derived from the body's `periodId` | Authorizes at the Period's Company; accounts must belong to it. |
| `POST /fixed-assets/{id}/record-depreciation`, `/assess-impairment`, `/dispose` | Authorized at the body Period's Company; the asset id is in the path | Since T19, the asset must belong to that same Company, else 404. |
| `POST /leave-accruals/{id}/remeasure`, `/utilize` | Authorized at the **leave accrual's own** Company, loaded by id | Period must also belong to it (T19). |

There is no route that lists or searches across Companies or Tenants: every list is `GET /companies/{companyId}/...`. Reports (balance sheet, profit and loss, cash flow, trial balance, working capital, aging, balances, VAT, tax) are all Company-scoped reads.

## 3. Tables and queries without a company key

- **Child tables with no company column** are listed in 1.3; their rows are only ever loaded through the parent (`bank_statement_lines` by reconciliation id, order lines by order id, and so on), and the parent lookup is the Company-scoped one. I did not find a code path that reads a child row by its own id from a request.
- **Repository lookups by id alone** exist for `Account`, `Period`, `JournalEntry`, `FixedAsset`, `LeaveAccrual`, `Customer`, `Supplier`, `OpeningImportBatch`, `TaxRule`/`TaxComputation`/`VatReturn`. Each caller I traced checks ownership afterwards: every account lookup is `.takeIf { it.companyId == ... }`; Period loads go through `PeriodRepository.findOwnedBy` (T19) and a guard test fails the build on a raw `findById` in `application/`; fixed assets and leave accruals are authorized at their own Company. `BankReconciliationRepository.findById` takes the Company id as a parameter (the only repository designed that way).
- **Two id-only lookups with no route**: `ReverseJournalEntryUseCase` (`journalEntryRepository.findById(entryId)`, no company check, allow-listed in the T19 guard, **not exposed by any route**) and `OpeningImportBatchRepository.findById` (not exposed). If a reversal route is added (needed for UAT H2), it must check the entry's Period belongs to the authorized Company; I would write that test first.
- **The route layer still does raw `periodRepository.findById`** in `FixedAssetRoutes` and `JournalEntryRoutes` before authorizing at the Period's own Company. Consistent, but CM asked for it to be folded into the guard; open item from T19.
- **No database-level isolation** (no RLS, no per-tenant schema): isolation is entirely application-level. `docs/Database_Tenant_Isolation_RLS_Scope.md` records the decision to hold off.

## 4. What GL expects from callers, and how the service accounts are scoped

**People (WEB):** a bearer token, and `X-Tenant-Id` set to the Tenant that owns the Company they are working in. A person with Memberships in several Tenants works today: the header selects which Tenant is being claimed, and GL checks it against the Company's real Tenant and against the person's membership in **that** Tenant.

**Service accounts (SOP, POP, IM, HR):** each has its **own Cognito app client and its own audience and its own named provider** in GL (`fish-jwt-service`, `-im`, `-hr`, `-pop`), set once to `isServiceAccount = true`. What GL enforces for them today:
- a valid token for that audience, with an `email` claim;
- `X-Tenant-Id` present and equal to the Company's own Tenant (they send a **deploy-time configured** Tenant, so each service can act in one Tenant only; per `RBAC_IM/HR/POP/SOP_Statement.md`);
- **nothing else**: no membership, no module, no access level, no Tenant scope on the credential, no endpoint allow-list. Any of the four can call **any** GL route (including reports, account creation and `POST /tenants/{tenantId}/companies`) for any Company whose Tenant it names in the header.

Education Runtime does not call GL directly; its financial events go through SOP.

**What T15 changes for callers** (once D5 is decided, as CM recommends: one Tenant per credential plus an endpoint allow-list): GL enforces a **per-credential scope** (which Tenant, or set of Tenants, and which routes), keyed on the credential's audience. Then the header can become optional for service callers (Option A in `GL_Tenant_Header_Service_Account_Options.md`), GL derives the Tenant from the Company and refuses it if it is outside the credential's scope, and **SOP, POP, IM and HR can drop their deploy-time Tenant values**. Callers must first declare themselves tolerant of GL changing (consumers-first): a service must send the Company on every call (it already does) and handle a new 403 for out-of-scope routes.

## 5. Isolation tests: what exists, and what I would add

**Exist today**
- **Cross-Company and cross-Tenant posting** (T19): `CrossCompanyPostingIsolationRouteTest` runs 9 posting routes for a person and a service credential, against another Tenant's Company and a sibling Company in the same Tenant, each with an own-Company control; plus the fixed-asset asset/period mismatch, leave-accrual use-case tests, `PeriodOwnershipGuardTest` (build fails on a raw period load) and the account-vs-Company check.
- **Header mismatch (`X-Tenant-Id` of another Tenant gives 403)** in 17 of the 27 route-test classes where it applies (28 route files have a test class; `/me` is human-only and has no header); **401 without a token** in nearly all.
- **Idempotency**: an integration test of the repository (`IdempotencyKeyRepositoryIntegrationTest`) proves the unique index on `(tenant_id, endpoint, key)` in Postgres. I found **no test asserting that the same key in two Tenants never replays across them** (added below).

**Gaps found by the audit (route families with no tenant-mismatch 403 test):** accounts-payable aging, accounts-receivable aging, customer balances, supplier balances, fixed-asset routes (which also have no 401 test), inventory posting context, payroll posting context, opening imports, trading profit and loss, VAT categories. `RecordSalesReturnRoutes` has no route-test class at all (its cross-Company case is covered by the T19 test).

**Would add (all tests, no behaviour change):**
1. **A route-inventory test** that walks every route registered in `infrastructure/web` and fails the build if a handler does not call the resolve/verify/authorize sequence, with an explicit allow-list (`/health`, `/jurisdictions`, `/me`). This is the "deny by default" for future routes.
2. **A generated isolation matrix** over every Company-scoped route: no token (401); header of another Tenant (403); missing header (400); person with a membership only in Tenant B asking for Tenant A's Company (403); unknown Company (404).
3. **"Guess the id" tests**: Tenant A asks for Tenant B's bank reconciliation, leave accrual or fixed asset by id (404 or 403, never the row), and for B's reconciliation `match`/`unmatch`.
4. **Data-bleed tests on reads**: seed two Companies in two Tenants with different postings; assert trial balance, balance sheet, profit and loss, cash flow, aging, journal-entry list, account list and fixed-asset register for A contain only A's rows.
5. **Idempotency**: the same key in two Tenants never collides or replays across them.
6. **Postgres integration**: repository `findAllByCompany` queries with two Companies; the child-table reads.
7. **After T15:** a service credential scoped to Tenant B gets 403 on Tenant A's Company, with and without the header, on every route; a route outside its allow-list gets 403; start-up fails when a service credential has no declared scope.

## 6. Estimate and order inside GL

| # | Step | Needs | Effort |
|---|---|---|---|
| G0 | **Fail closed**: reject every token on a service provider whose audience is unset (F-T15-1), and make `POST /tenants/{tenantId}/companies` people-only (F-T15-2). Adds refusals only. | CM to confirm the four variables are set in production and that no service calls the company route | about 0.5 day |
| G1 | **Isolation tests** 1 to 6 above, filling the audited gaps, and folding the two raw period loads into the guard | nothing | 1 to 1.5 days |
| G2 | **Per-credential scope** in configuration (credential audience to the Tenant or Tenants it may act for), enforced in `verifyClaimedTenant` and the Company resolution; GL refuses to start when a credential has no declared scope | **D5** (Femi), and where the mapping lives (GL configuration versus Cognito scope), CM for Terraform and secrets | 1 day plus 0.5 day of tests |
| G3 | **Endpoint allow-list** per credential (SOP, POP, IM and HR each call a small route subset; the exact lists are in `RBAC_GL_Statement.md` section 3.2, to be confirmed by each service) | the four services confirm their routes | 1 day |
| G4 | **Header optional for service callers** (GL derives the Tenant and checks it against the credential's scope); **consumers then drop** their deploy-time Tenant values | G2, G3, and each consumer declaring first | 0.5 day in GL |

Total about **4 to 5 working days** in GL; G2 to G4 (the T15 proper, "two to three days" in the SPUTO) wait for D5. G0 and G1 do not, and I would start with them.

**Release order across services (consumers first):** GL ships G0 and G1 on its own; G2 and G3 ship with the new scope configuration set by CM **before** the enforcement turns on (log-only first would be safer than a hard flip, and I would propose that); consumers then remove their Tenant values after G4 is live.

## 7. What I did not verify, and what I need

- Not checkable from this repo: whether the four `FISH_JWT_SERVICE_AUDIENCE*` variables are set in the live task definition (CM); what each consumer sends today beyond what their own statements say.
- **Femi:** D5; whether `POST /tenants/{tenantId}/companies` should be people-only.
- **CM:** the variables check above, Terraform and secrets for per-credential scope, and release order.
- **SOP, POP, IM, HR:** the exact GL routes each credential needs, so the allow-list is right the first time.
