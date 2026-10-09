# T15 (multi-Tenant first): POP's statement

**From:** Purchase Order Processing (POP) session. **Date:** 2026-10-09. **Written against:** POP `origin/master` at 8889cbf (POP :34), docs only, no code. **Answers CM's six points** from the T15 request: Femi's decision of 2026-10-09 is that any number of Tenants must work on this one deployment, with the first Tenant's data never exposed to another (isolation is the acceptance test), deny by default, and a missing or unknown Company/Tenant mapping is a 403/404 and never a fallback to the old Tenant. Everything below was read from the code.

**The short version.** POP already scopes every business route and every table by Company, and Company ids are random UUIDs, so most of the data separation is in place. What binds POP to one Tenant is the **authorization check**, the **`X-Tenant-Id` it sends to GL**, and the **service-account principals** it uses to call GL and IM. Those three are what T15 has to change in POP. POP's own work is small; the hard parts depend on GL and EA decisions (section 4).

---

## 1. Every place POP binds to a Tenant or a fixed Company

| Binding | Where | What it does today |
|---|---|---|
| `POP_EA_TENANT_ID` (required at start-up) | `Application.kt:209` into `PopMembershipAuthorizer(eaMembershipGateway, eaTenantId)` | `resolve()` picks the caller's one Membership whose `tenantId` equals this value (`memberships.firstOrNull { it.tenantId == tenantId }`). A caller with no Membership in that Tenant is refused with "No active Membership in this deployment's Tenant", **even if EA lists the requested Company under another Tenant they belong to**. This is the main Tenant binding. |
| `POP_GL_ENGINE_TENANT_ID` (required at start-up) | `Application.kt:131` into `KtorGlEngineGateway(tenantId)` | Sent as `X-Tenant-Id` on **every** GL call (`authenticated()` in `ktor_gl_engine_gateway.kt:110`): purchase-posting-context, record vendor obligation, record vendor payment. One header value for the whole process. |
| `POP_GL_ENGINE_COMPANY_ID` | **Gone.** | No longer read since POP :31 (Company fix, 2026-10-08). The posting Company is the request path Company, which the route has already checked owns the order. It is still mentioned in code comments only (`Auth.kt` KDoc, lines 121 and 129, and a note at `Application.kt:137`). CM will drop the variable from the task definition. |
| GL service account (`POP_GL_ENGINE_SERVICE_ACCOUNT_*`, `POP_GL_ENGINE_COGNITO_REGION`) | `CognitoServiceAccountTokenProvider` at `Application.kt:159` | One Cognito user for the whole process. GL decides what that principal may do. Its **Tenant** is whatever GL's `User`/`Membership` row for it says, set up by hand once (`docs/POP_GL_Service_Account_Closure_Plan.md`). It cannot be a member of more than the Tenants someone grants it. |
| IM service account (`POP_IM_SERVICE_ACCOUNT_*`, `POP_IM_COGNITO_REGION`) | `CognitoServiceAccountTokenProvider` at `Application.kt:187` | Same shape for IM. POP sends **no** Tenant header to IM; IM's routes carry the Company in the path (`/companies/{companyId}/items/...`) and IM decides. |
| `POP_EA_BASE_URL`, `POP_GL_ENGINE_BASE_URL`, `POP_IM_BASE_URL` | start-up | One deployment of each sibling. Not a Tenant binding. |
| `POP_JWT_ISSUER`, `POP_JWT_AUDIENCE`, `POP_JWT_JWKS_URL` | start-up | One identity provider and audience for human tokens. Not a Tenant binding (all Tenants' users sign in through the same Cognito pool). |
| `POP_PORTAL_BASE_URL` | start-up | One supplier-portal host for the links in order emails. Not a Tenant binding; a second Tenant's suppliers get links on the same host. |
| `POP_NOTIFICATION_FROM_EMAIL` | start-up | One SES sender for all order emails. Not a Tenant isolation issue, but the sender name is not per business. |
| `POP_CORS_ALLOWED_ORIGIN` | start-up | One web origin. Not a Tenant binding. |
| `POP_DB_*` | start-up | One database for every Company. See section 3. |
| Start-up singletons | `Application.kt` | The authorizer (one Tenant), the GL gateway (one Tenant header), two token providers. Nothing else in POP holds a Tenant or Company. |

POP stores **no Tenant id anywhere**. It stores the Company (`entity_id`/`company_id`), and learns the Tenant only from EA's `/me` on each request.

## 2. Routes not scoped by a Company in the path

Every route under `/api/companies/{companyId}/...` is Company-scoped and checked per request (read below). The routes outside that prefix are:

| Route | Auth | What it returns / changes | Cross-Tenant risk |
|---|---|---|---|
| `GET /health` | none | `{"status":"ok"}` | none |
| `GET /api/supplier-portal/purchase-orders` | per-order link token | the fulfilment view of **one** order (its lines, waybills, proposals, reports, returns) | The token is a random secret stored hashed, with expiry and a revoked flag. The Company is derived from the order the token belongs to. A guessed or stolen token reaches only that order. **No rate limiting** on token guesses (flagged in the RBAC statement). |
| `POST /api/supplier-portal/purchase-orders/waybill` | link token | attaches a waybill to that one order | same |
| `POST .../negotiation-proposals` | link token | raises a proposal on that one order | same |
| `POST .../discrepancy-reports` | link token | raises a report on that one order | same |

There are **no flat list routes** like SOP's `GET /api/sales`: `GET /suppliers`, `/purchase-orders/pending-action`, `/purchase-orders/fulfillment`, `/accounts-payable-due-date-aging` and `/purchase-order-settings` are all under `/companies/{companyId}` and filter by that Company in the repository query (`findAll(companyId)`, `findByStatuses(companyId, …)`, `findUnsettled(companyId)`, `findByCompanyId`).

**Repository methods with no Company filter (verified, not routed):** `ReturnOutwardsRepository.findAll()` is unscoped and has **no caller**; it should be deleted as part of T15. The `findById`/`findByPurchaseOrderId`/`findBySecret` finders take only an id, so their Company safety comes from the callers: the routes check `PurchaseOrder.entityId == path Company` (`verifyPurchaseOrderCompany`), nested records are checked to belong to that PO (live 2026-10-07), suppliers are checked against the path Company in the use cases (live 2026-10-07), and a foreign record answers exactly like a missing one.

## 3. Tables without a company key, and queries not filtered by it

| Table | Company key | Notes |
|---|---|---|
| `suppliers` | `entity_id` | filtered in `findAll(companyId)`; `findById` guarded in use cases |
| `purchase_orders` | `entity_id` | plus `po_number` unique per Company (V16) |
| `purchase_order_lines`, `purchase_order_received_lines` | via `purchase_order_id` | child rows; only reached through their order |
| `order_access_tokens` | via `purchase_order_id` | looked up by hashed secret only (by design: the portal has no Company in the path) |
| `waybills`, `negotiation_proposals`, `discrepancy_reports`, `returns_outwards` | via `purchase_order_id` | no Company column; the Company is the order's. All reads in routes go through an order whose Company was checked. |
| `vendor_invoices` | `company_id` | `findUnsettled(companyId)` filtered |
| `company_purchase_order_settings` | `company_id` (key) | one row per Company |
| `purchase_order_sequences` | `company_id` (key) | per-Company PO number counter |
| `pop_audit_log` | `company_id` (nullable) | null only for a record whose order cannot be found |

**Gaps:** none of the child tables can be filtered by Company without a join to `purchase_orders`. That is fine today because every route reaches them through a checked order, but it means **a new query written without that check would not be Company-filtered by the database**. There is no row-level security (the platform-wide decision is recorded in `docs/Database_Tenant_Isolation_RLS_Scope.md`). Company ids are random UUIDs, never reused, so two Tenants' Companies cannot collide in the same column. The database holds every Tenant's rows in the same tables.

## 4. Every outbound call, and how the Tenant/Company would be passed per request

| Call | Today | Per request after T15 |
|---|---|---|
| **EA `GET /api/me`** (every authorized request) | caller's own bearer token; Tenant-agnostic (EA returns all the caller's Memberships) | **No change to the call.** Only the choice of Membership changes: instead of the env Tenant, POP finds the Membership whose `companies` contains the path Company. If none lists it, or the Company is not there, **deny (403)**, never fall back. If a Company appeared under two Memberships (it should not), deny and log. |
| **GL** purchase-posting-context, record vendor obligation, record vendor payment | service-account token plus `X-Tenant-Id` = env value | **`X-Tenant-Id` = the Tenant of the Membership that authorized this request** (the same `tenantId` found above), passed down to the gateway as an argument instead of a constructor value. The Company id is already per request. **Dependency on GL:** GL authorizes the service account against that Tenant, so the service account needs a GL Membership/credential in every Tenant POP serves, or GL needs the scoped-credential decision (R7/D5; `docs/GL_Tenant_Header_Service_Account_Options.md`). POP cannot decide this. |
| **IM** goods issue (return dispatch) and goods receipt | service-account token, Company in the path, no Tenant header | Company already per request. **Dependency on IM:** IM authorizes the service account at that Company, so the same per-Tenant credential question applies. POP changes nothing. |
| **SES** (order emails) | one sender | unchanged; no Tenant data in the call |

Calls that start from the supplier portal (no human, no membership) are POP-local; they make no GL, IM or EA call.

The single new thing POP must carry per request is the authorized Tenant id, from the authorizer to the three GL-calling routes (match, pay, return dispatch) and the use cases behind them. It must come from the authorization result for that request, never from a body field or a header supplied by the caller.

## 5. Tests that would prove isolation (Tenant A cannot reach Tenant B)

All are API-level tests with two Tenants and two Companies in the EA stub, so they can run in the existing end-to-end suite, plus Postgres-backed tests for the data paths.

1. **Membership selection:** a caller who belongs to Tenant A only, asking for Tenant B's Company, gets 403 on every route (a table-driven test over every route). The same for a caller in both Tenants asking for a Company that neither Membership lists.
2. **No fallback:** a Company missing from `/me`, a `/me` with no memberships, and an unknown Company id all give 403/404; none uses the old env Tenant (the env variable is deleted, so there is nothing to fall back to).
3. **List isolation:** two Companies in different Tenants each create suppliers, orders, returns and vendor invoices; every list route for A shows only A's rows and never B's (suppliers, `pending-action`, `fulfillment`, aging, settings).
4. **Guess by id:** with B's order id, supplier id, return id, proposal id, report id, vendor invoice id, A (authorized for A's Company in the path) gets 404 on get, send, approve, match, pay, cancel, amend, every nested route, and supplier activate/deactivate. This repeats the existing nested-id and supplier tests with a second Tenant.
5. **Write isolation:** A cannot create an order against B's supplier, import an opening payable against it, or change B's settings.
6. **Outbound Tenant:** for a request authorized under Tenant B, the GL gateway is called with `X-Tenant-Id` = B's Tenant and B's Company, never A's; assert it on every GL-calling route (match, pay, dispatch), including when Tenant A's requests are interleaved concurrently.
7. **Supplier portal:** a link token for A's order cannot read or write B's order (wrong order id in the body is ignored; the order comes only from the token); an unknown token is 401; a revoked or expired token is 401.
8. **Sequence and audit:** PO numbers count per Company across Tenants; a PO number from A never appears in B's responses; the audit log rows carry the right Company.
9. **Start-up:** the application starts with neither `POP_EA_TENANT_ID` nor `POP_GL_ENGINE_TENANT_ID` set (they are gone), and refuses to start if a required endpoint variable is missing.

## 6. Estimate and order of work inside POP

| # | Work | Estimate | Needs |
|---|---|---|---|
| 1 | Authorizer: choose the Membership that lists the path Company; deny otherwise; return the Tenant id with the actor; remove `POP_EA_TENANT_ID` | 0.5 day + tests | none |
| 2 | GL gateway: take the Tenant id per call, drop the constructor value; thread it through the three GL-calling routes and use cases; remove `POP_GL_ENGINE_TENANT_ID` | 1 day + tests | the GL credential decision (section 4) before it can be proven live |
| 3 | Delete `ReturnOutwardsRepository.findAll()`; remove the stale `POP_GL_ENGINE_COMPANY_ID` comments | 0.25 day | none |
| 4 | The isolation test suite in section 5 (two-Tenant fixture, the table-driven route test, interleaved outbound test) | 1.5 to 2 days | none |
| 5 | Playbook update (access section, environment variables) | 0.25 day | none |

**Total: about 3.5 to 4 days of POP work.** Order: 4 first as failing tests (they define the acceptance test), then 1, 3, 2, 5. Steps 1, 3 and 4 need nothing from anyone; step 2 is complete in code without GL's decision but cannot be shown working for a second Tenant until GL and EA settle which principal POP's service account acts as in each Tenant (T15 in `docs/RBAC_SPUTO.md`, R7).

## Objections and things the plan should settle before any code

- **The service-account question is the real work.** POP can pass the right Tenant and Company on every call, but if GL and IM accept the single service principal for any Tenant, POP's per-request Tenant header is the only thing keeping Tenants apart, and it is a header POP sets. Isolation then rests on POP never being wrong. GL's validating the Tenant against the credential (R7) is what makes it safe. I would not call isolation proven until that exists.
- **Deployment-time Tenant for audit and operations:** several runbooks and the playbook say "one Tenant per deployment". Those need updating together with step 1.
- **No row-level security:** isolation is application-enforced in POP, as the platform decided (`docs/Database_Tenant_Isolation_RLS_Scope.md`). The tests above are the only guard against a future query written without a Company check. A Company column on the child tables (waybills, proposals, reports, returns) would let those queries filter by Company directly. That is an optional hardening I can add in step 4's wake if you want it, about 1 day with a backfill.
- **T6 (return-dispatch idempotency, V17)** is held for IM's verification and is unaffected: its key already contains the Company.

---

## Addendum (2026-10-09): the second wall, Company against Company inside one Tenant

Femi's definition of T15 has two walls: Tenant against Tenant, **and** Company against Company inside one Tenant (each business has its own GL and its own data; consolidation comes later). The statement above covers the first wall. This covers the second.

### Does any POP query join across Companies today? No.

- I searched POP's persistence layer for `innerJoin`, `leftJoin`, `crossJoin`, `join(`, `JOIN` and `union`: **no matches.** Every query reads one table, filtered by an id or by one Company.
- The only multi-table read is the audit helper `AuditRecorder.companyOfPurchaseOrder`, which looks up one order by its id to learn its Company. It does not combine Companies.
- Every list is filtered by exactly one Company: `findAll(companyId)` (suppliers), `findByStatuses(companyId, …)` (orders), `findUnsettled(companyId)` (vendor invoices, aging), `findByCompanyId` (settings). There is no "all my Companies" read anywhere, and no total across Companies.
- The authorization check is already per Company, not per Tenant, for the module and the level: `membership.accessLevelAt(companyId)` and `"POP" in membership.grantedModulesAt(companyId)`. An owner with Companies A and B who has the module granted on A only is refused on B (an existing test covers a caller granted at a different Company than the path).
- Posting is per Company too: the GL posting context (period, accounts) is fetched for the path Company on every match, payment and dispatch, and IM is called with the order's own Company.
- **One real consequence for "each business has its own GL":** because the Tenant is fixed in the environment today, the same GL Tenant header is sent for A and B. After T15 the Tenant comes from the authorized Membership, and A and B in one Tenant share it correctly. Nothing in POP would put A's posting into B's GL: the Company id in every GL call is the order's, and the order was checked against the path Company.

### Same-owner cross-Company isolation tests to add (to section 5)

Setup: one user, one Tenant, an Owner Admin or staff member with the module granted on **both** Company A and Company B, so authorization passes on both and only the record checks stand in the way.

10. **Lists never mix:** create suppliers, orders, returns, proposals, reports and vendor invoices under A and under B. Each list route under A's path returns only A's rows, and under B's path only B's (suppliers, `pending-action`, `fulfillment`, aging, settings, and the PO numbers: each Company counts from 1 on its own).
11. **A record id under the other Company's path is 404:** with the same authorized user, a B-scoped call using an A record id answers 404 (the same body as a missing record, never 403 or the record) on get, send, approve, cancel, amend, match, pay, receive-line, every nested route (proposals, reports, returns approve/reject/dispatch/credit-note) and supplier activate/deactivate. The same for A-scoped calls with B's ids.
12. **Cross-references are refused:** an order created under B with A's supplier id is `supplier_not_found`; an amend or an accepted proposal never makes a replacement order under a different Company than the original.
13. **Settings stay separate:** changing A's approval threshold or match tolerance changes nothing for B, and an order over A's threshold needs approval in A and not in B.
14. **Posting goes to the right ledger:** for each Company, the GL gateway receives that Company's id and its own posting context on match, pay and dispatch, and IM receives the order's Company on dispatch, with calls for A and B interleaved.
15. **Audit rows carry the right Company** for records created by the same user in A and in B.

These need no new production code; they extend the same two-Company fixture as tests 1 to 9. The first wall's tests (different Tenants) and these (same Tenant) should be one table-driven suite parameterised by "same Tenant" and "different Tenant", so a future route cannot pass one and skip the other.
