# T15: how SOP binds to a Tenant and a Company today, and what multi-Tenant needs (SOP statement)

**Status: 2026-10-09, SOP session. Statement only; nothing changed, no code.** Written at CM's request for the T15 plan (`docs/T15_MultiTenant_SPUTO.md` will be assembled from the service statements), in the frame CM set: (1) bindings, (2) routes not scoped by a Company in the path, (3) tables and queries without a company key, (4) outbound calls, (5) isolation tests, (6) estimate and order. Read from SOP `origin/master` `b03ad2c` (task definition :46) and cross-checked against `docs/T15_GL_Statement.md` and `docs/T15_EA_Statement.md`. Items I could not check from code are marked *(not verified)*.

**Femi's ruling (2026-10-09), which this statement designs to:** a Tenancy is a business owner bringing his Companies onto the platform. **Two walls, both designed and tested:** (1) **Tenant against Tenant**, hard: nothing of one owner is ever visible to another owner, and the first Tenant's data is never exposed (isolation is the acceptance test); (2) **Company against Company inside one Tenant**: no read, report, posting, order, customer lookup or id-guess may mix two Companies of the same owner. Consolidation across a Tenant's Companies is later. **Deny by default:** a missing or unknown Company or Tenant mapping is a 403 or 404, never a fallback to the old Tenant.

## 0. The short version

- **SOP is single-Tenant by construction, so today it is fail-closed, not leaking.** One variable pins the Tenant for authorization (`SOP_EA_TENANT_ID`) and one pins it for every call to GL (`SOP_GL_ENGINE_TENANT_ID`, sent as `X-Tenant-Id`). A person with no membership block for that Tenant gets 403 on everything (the UAT tester who onboarded a second Tenant, 2026-10-09). No variable carries a Company id: the Company is already per request.
- **The Company wall is mostly built.** Since 2026-10-07 every Sales, return, complaint, Bill, customer, report and invoice-email route is judged at the record's own Company; reads of another Company's record are 404, writes 403; the sale's customer must belong to the Company. What is missing is that this is **enforced in the route layer after loading the record**, not in the data model or the query.
- **What breaks the moment a second Tenant is let in** (section 2): (a) the Education Runtime service credential reads **every** order in the database (`SopCompanyScope.All`); (b) **facility headroom has no Company at all**: it is read and opened by facility id alone; (c) several repository methods return every row and filter in memory (`findAll()`), and every lookup by id relies on a check made afterwards; (d) the authorizer picks the Membership block by one fixed Tenant instead of the Tenant that owns the Company asked about.
- **The fix has three parts:** give every row its own Company key and make every query filter by it (the wall moves into the data layer); derive the Tenant per request from the Company (humans from their `/me`, services from an EA lookup); scope the service credential to a Company set. **Estimate: about 6 working days in SOP** (section 6), order in section 6.

## 1. Where SOP binds to a Tenant or a fixed Company

| Binding | Where | What it does |
|---|---|---|
| `SOP_EA_TENANT_ID` | `Application.kt` (`productionModule`), passed to `SopMembershipAuthorizer(gateway, tenantId)` (`Auth.kt`) | Every authorization picks `memberships.firstOrNull { it.tenantId == tenantId }`. No such block = 403 "No active Membership in this deployment's Tenant" for **every** call, whatever the Company. |
| `SOP_GL_ENGINE_TENANT_ID` | `Application.kt`, held by `KtorGlEngineGateway`; `ktor_gl_engine_gateway.kt` `authenticated()` | Sent as `X-Tenant-Id` on **every** GL call (sale, collection, sales return, posting context, customer balances, invoices). GL requires it to equal the Company's real Tenant (`T15_GL_Statement.md` 1.1), so any Company outside the fixed Tenant would be refused by GL even if SOP let it through. |
| GL service identity | `SOP_GL_ENGINE_SERVICE_ACCOUNT_*` (one Cognito user), `CognitoServiceAccountTokenProvider` | One credential for **all** Companies; not bound to a Tenant or Company. The same token is presented to **EA** for owner-contact (RBAC B5: should be its own audience). |
| IM service identity | `SOP_IM_SERVICE_ACCOUNT_*` (one Cognito user), `SOP_IM_BASE_URL` | One credential for all Companies. The Company travels in the URL (`/companies/{companyId}/items/...`). |
| Education Runtime inbound credential | `SOP_JWT_SERVICE_AUDIENCE_SCHOOLADMISSIONS` | A valid token becomes `isServiceAccount = true`: skips Membership, Company and module checks; `readableSopCompanies()` returns `All`. Bound to no Tenant or Company. |
| EA base URL | `SOP_EA_BASE_URL` | `GET /me` with the caller's own token; owner-contact with SOP's service token. |
| Fixed Company | **none.** No environment variable, constant or startup singleton holds a Company id. (IM and POP had one; checked for SOP 2026-10-08.) |
| Database | one database (`sop_*`), one schema; no tenant column anywhere | Isolation is entirely application-level. |
| Startup singletons | the GL and IM gateways, the authorizer, `CompanyResolver`, the repositories | All built once with the fixed Tenant; none holds per-Company state. |

## 2. Routes not scoped by a Company in the path, and what they return

SOP mounts three families. "Flat" routes carry no Company in the path; today they are judged at the record's own Company after it is loaded.

| Family | Routes | Today | Leak once two Tenants exist |
|---|---|---|---|
| **Path Company** (`/api/companies/{companyId}/...`) | customers (GET, POST), customers-with-balances, sales-performance, returns-analytics, inventory-availability, sales-invoices `/{n}/email` and `/emails` | READ or WRITE at that Company | None by design, provided the Tenant is derived from that Company (section 4). Reports read **all** orders and filter in memory by the Company's customers: correct, but they load every Tenant's rows (defence in depth, performance). |
| **Company in the body** | `POST /api/sales`, `/sales-orders/{id}/collections`, `POST /record-sale` (legacy), `/return-requests/{id}/inspect`, `/issue-credit-note`, `/bills-for-collection/{id}/collect` | WRITE at the body Company; for records it must equal the record's | None if the record's Company is its own column (not derived through a join). |
| **Flat, judged at the record's Company** | `GET /api/sales` (optional `?companyId=`), `GET /sales-orders/{id}`, `POST /sales-orders`, `POST /sales-orders/{id}/cancel`, `/return-requests*`, `/customer-complaints*`, `/bills-for-collection` (present, accept, mark-due) | Lists return only the Companies the caller can read; by-id routes 404 or 403 | `GET /api/sales` is the **cross-Tenant list**: it must return only the caller's Companies across **all** the caller's Tenants, and nothing for a service credential unless its Company set says so. By-id routes are safe only while the Company check runs after every load (one missed route = an id-guess leak). |
| **Flat, NOT scoped by any Company** | `GET` and `POST /facilities/{facilityId}/headroom` | Tenant-wide: any READ caller reads any facility's headroom by id; any WRITE caller opens one. `facility_headrooms` has no Company key. | **A real leak and a real write hole** the moment two Tenants exist: Tenant B can read or open Tenant A's facility headroom by guessing a facility id. |
| **Service credential (Education Runtime)** | every route except invoice email | `authorizeSop` returns true at once; `readableSopCompanies()` returns `All` | **Reads and writes every Company's orders, customers and returns across all Tenants.** The single largest hole. |
| Public | `GET /health` | Liveness only | None. |

Also relevant: `GET /api/sales` and the returns and complaints lists load rows with `findAll()` and filter in memory; correct today, but it is the pattern that fails first under load and under a missed filter.

## 3. Tables and queries without a company key

| Table | Company key | Queried how |
|---|---|---|
| `customers` | `entity_id` (the Company) | `findAll(companyId)` filtered in SQL; `findById(id)` then checked |
| `sales_orders` | `entity_id` (the Company since 2026-10-07; older rows carry a random id) | `findByCompanies(set)` filtered in SQL; `findById(id)` then checked; `findAll()` used by reports and service accounts |
| `sales_order_lines`, `sales_order_aval_confirmations` | through the order | loaded with their order |
| `return_requests`, `return_request_lines`, `return_line_dispositions` | **none**: Company only through `customer_id` to `customers.entity_id` | `findAll()` filtered in memory through `CompanyResolver`; `findById(id)` then checked |
| `credit_notes` | **none**: through `return_request_id` | `findAll()` and `findByReturnRequestId` |
| `customer_complaints` | **none**: through `return_request_id` | `findByReturnRequestId`, `findById` |
| `bills_for_collection` | **none**: through `sales_order_id` | `findById` only |
| `facility_headrooms` | **none at all** | `findByFacilityId` |
| `invoice_email_sends` | `company_id` | filtered in SQL |
| `idempotency_keys` | `company_id` in the primary key | filtered in SQL |

**Proposal:** every row that stands for a business record gets its **own `entity_id`** (return requests, credit notes, complaints, Bills, facility headrooms), set at creation from the authorized Company, backfilled in the migration from the customer or order, and **every repository method takes the Company (or the allowed Company set)** so a query by id is `WHERE id = ? AND entity_id IN (?)`. The route-layer check stays as a second layer. `CompanyResolver` then disappears from the hot path. Legacy rows: WEB reports the production data was wiped (not verified by SOP); the migration must tolerate both empty tables and old rows and backfill unresolvable rows to a quarantine value that no Company can read (deny by default).

## 4. Outbound calls and how the Tenant and Company would be passed per request

| Call | Today | Per request under T15 |
|---|---|---|
| EA `GET /me` (humans) | caller's own token; block picked by the fixed Tenant | Same call. The Tenant for a request is **the block whose `companies` contains the request's Company** (`T15_EA_Statement.md`: `tenants[].companies` carries it). Exactly one block must match; none or several = 403/404. A Company is in exactly one Tenant. |
| Authorization of a list (`GET /api/sales`) | Companies readable in the fixed Tenant | Union of the readable Companies across **all** the caller's blocks |
| GL (all calls) | fixed `X-Tenant-Id` | `X-Tenant-Id` = the Company's Tenant, resolved per request; GL already requires it to equal the Company's real Tenant. The gateway takes the Tenant as a parameter instead of holding it. |
| GL token | one service user for everything | stays one identity but scoped (R7/T15); the Tenant is asserted per call |
| IM | Company in the URL | unchanged; IM derives its own Tenant from the Company (IM's own T15 statement, not yet written when this was read) |
| EA owner-contact | by Company | unchanged; its own audience (B5) |
| Service-originated calls with no `/me` (Education Runtime, the Epic 13 inbox) | bypass | **Needs an EA answer for Company to Tenant** (EA internal route `GET /api/internal/companies/{companyId}` returning the Tenant) **and a credential bound to a Company set**; an unknown or out-of-set Company is 403 |
| Idempotency keys | scoped by `company_id` | unchanged (a Company belongs to one Tenant) |

## 5. Tests that PROVE the isolation (both walls)

Written first, per wall, against the real routes with two Tenants and a Company pair inside one Tenant (fixtures: Tenant A with Companies A1 and A2 held by one owner; Tenant B with B1).

**Wall 1, Tenant against Tenant (A and B never see each other):**
1. A user of B1 lists sales: none of A1's or A2's orders appear; `?companyId=A1` is 403.
2. A user of B1 fetches, cancels, collects, emails, returns, complains against, presents a Bill for, or reads the headroom of an A1 record **by id**: 404 (read) or 403 (write); the record is unchanged.
3. A user with a membership **only in Tenant B** and none in A: `GET /api/sales` returns B's Companies only; with no matching Tenant block at all the answer is 403, never an empty fallback to A.
4. The Education Runtime credential scoped to Company set S: reads and writes only inside S; any other Company, in any Tenant, is 403.
5. GL calls for a B1 sale carry B's `X-Tenant-Id`, never A's (assert the header per call); a request whose Company has no Tenant mapping fails closed, never sends the old Tenant.
6. Facility headroom opened for an A1 facility cannot be read or opened by B1 (needs the Company key).
7. **The first Tenant's regression:** every existing test for the first Tenant still passes unchanged, plus a snapshot test that its list and report outputs are byte-identical before and after a second Tenant exists.

**Wall 2, Company against Company inside one Tenant (one owner holds A1 and A2):**
8. A1's sales, customers, returns, complaints, Bills, reports and balances never appear in an A2-scoped list or report.
9. An A2-scoped call with an A1 record id: 404 or 403 on every route family (orders, collections, cancel, returns, credit notes, inspection, complaints, Bills, customer lookup, invoice email by number).
10. A sale in A2 naming an A1 customer: 404 `customer_not_found` (built); a return request for an A1 customer with an A2 order: refused.
11. Invoice numbers cannot cross Companies: `INV-` collisions are resolved inside one Company only.
12. A user with WRITE at A1 only cannot write at A2 even in the same Tenant, and the Owner holding both sees them as two separate sets (no merged totals).
13. Static guard test: no repository method returns rows without a Company argument except an allow-listed few (reports for service use), and a failing test names any new one (GL did the same with its T19 guard).

## 6. Estimate and order inside SOP

| # | Work | Days | Depends on |
|---|---|---|---|
| 1 | **Data model first:** `entity_id` on return requests, credit notes, complaints, Bills and facility headrooms, backfill and quarantine in one additive migration; repositories take the Company set; remove `findAll()` from request paths; the static guard test (test 13) | 1.5 | none |
| 2 | **Facility headroom becomes Company-scoped** (route, use cases, migration): from the first row onward the facility belongs to one Company | 0.5 | 1 |
| 3 | **Per-request Tenant:** `CompanyTenantResolver` from the caller's `/me`; the authorizer picks the block by the Company and the readable set across all blocks; deny when none or several match | 1 | EA confirms the `/me` shape and the one-Tenant-per-Company guarantee |
| 4 | **GL gateway takes the Tenant per call**; drop `SOP_GL_ENGINE_TENANT_ID` and `SOP_EA_TENANT_ID` (keep an optional allow-list while rolling out); fold in the structured `sop_access_denied` reasons (parked branch `fix/sop-403-reason-log` 06a27b8) | 0.75 | 3 |
| 5 | **Scope the Education Runtime credential** to a Company set and an endpoint allow-list; the Company to Tenant answer for service calls | 0.75 | D5, EA internal route, GL's credential design |
| 6 | **Isolation test suite** (section 5, both walls) | 1.5 (written alongside 1 to 5) | 1 to 5 |
| 7 | Owner uplift (RBAC T7) simplifies to a per-Company check once EA's explicit assignments exist | 0.25 | EA T6 |
| | **Total** | **about 6.25 days** | |

**Order:** 1 and 2 first (the wall in the data), then 3 and 4 (the Tenant per request), then 5 (the credential), with the tests written before each step and the first Tenant's regression suite green at every step. One reviewed release per step; steps 1 and 2 are invisible to users. **Nothing starts before CM publishes the T15 plan.**

## 7. What SOP needs from the others, and one objection

- **EA:** confirm `/me` `tenants[].companies` is complete for every Company a person may act in (the earlier gap: "Company missing from `/me`") and that a Company belongs to exactly one Tenant; the internal Company to Tenant route for service calls (RBAC B4); the "add a Company assignment to an existing member" gap noted by CM, which blocks a second Company for an invited member.
- **GL:** keep requiring `X-Tenant-Id` equal to the Company's Tenant (SOP will send the right one per call); confirm what the service credential scope will look like (`T15_GL_Statement.md` F-T15-2 and the open D5).
- **Education Runtime:** the list of SOP routes it will call (today customer creation only; Epic 13 adds an inbox), so the allow-list is exact.
- **IM and POP:** their own statements; SOP's per-line stock key (T5) already carries the Company.
- **Objection:** Femi's decision drops the "deployment per school Tenant" option I described for Epic 13; the Epic 13 SOP half should now be written against this multi-Tenant design (Company-scoped inbox paths, a scoped ER credential), and its isolation tests become part of section 5.
