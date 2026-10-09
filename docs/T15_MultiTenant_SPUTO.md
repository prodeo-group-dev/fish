# T15: multi-Tenant on one deployment (SPUTO plan)

**Status:** plan v1, 2026-10-09, CM. Assembled from the service statements (`docs/T15_{EA,GL,IM,POP,SOP,WEB}_Statement.md`, `docs/T15_GL_G2_G3_Design.md`, `docs/EA_Company_Tenant_Lookup_Design.md`). **HR's statement is the last one outstanding** (section 7). Nothing in this document is built except where marked DONE. No service code for M1 onward starts before the owner of that service has read this plan and replied with its order.

## 1. Scope (Problem Specification)

**Definition (Femi, 2026-10-09).** A Tenancy is a business owner bringing his businesses (Companies) onto the platform; some businesses have specialist runtimes (a school). One owner can have many businesses. **One Owner Admin per Tenant** (no joint owners until real requests arrive).

**The problem.** SOP, POP, IM and HR are each bound to ONE Tenant by an environment variable (`*_EA_TENANT_ID`, `*_GL_ENGINE_TENANT_ID`). A second business owner who onboards (the UAT tester, 2026-10-09: Tenant `15734cdc-...`, Company xyz `7ceb0fa9-...`) gets 403 "No active Membership in this deployment's Tenant" from all four, by design. GL and EA already work for any Tenant. Rollout needs many owners side by side.

**Two walls, both designed and tested:**
1. **Tenant vs Tenant**, hard: nothing of one owner is ever visible to another owner.
2. **Company vs Company inside one Tenant**: each business has its own GL and data; no read, report, posting, stock count, order or lookup mixes two Companies of the same owner. Consolidation is later functionality, built on purpose.

**Principle.** Deny by default. An unknown Company or Tenant mapping is 403/404, never a fallback to the old Tenant. Human-readable ids (Tenancy ID, Business ID) are labels only; the Tenant/Company UUID stays the key everywhere.

## 2. Decisions made (Femi, my session)

| # | Decision |
|---|---|
| T15-D1 | Build multi-Tenant FIRST; no stopgap by re-pointing the env vars; sign-up policy (open vs invite-only) is still open. |
| T15-D2 | One Owner Admin per Tenant; two walls (above). |
| T15-D5 | Service logins (SOP/POP/IM/HR to GL) stay valid for all Tenants, limited to an endpoint allow-list; GL verifies on every service call that the Company belongs to the Tenant. No per-Tenant service logins, no token pass-through. |
| T15-A | "Option A": a service login may OMIT `X-Tenant-Id`; GL derives and verifies the Tenant from its own Company record. People keep the strict contract (missing 400, wrong 403). So services need not know a Tenant for GL calls and EA's Company-to-Tenant lookup route stays unbuilt. |
| T15-L | GL's own `companies.tenant_id` is the authority on the service path (no EA call, no GL Cognito client). |

## 3. What each service's statement found

| Service | Binding to one Tenant | Real leak when a 2nd Tenant arrives | Estimate (own) |
|---|---|---|---|
| **EA** | none for people; `/me` carries each Tenant's Companies; a Company belongs to one Tenant (index `ux_tenant_companies_company_id` to be confirmed in production, E1) | support thread open to staff (FIXED, owner-only, live); no add-assignment route (RBAC backlog) | E6 tests DONE |
| **GL** | none (its Tenancy tables dropped, V23); callers' header only | service credentials blanket: G2 tests DONE, G3 allow-list live in log mode, **G4 built and handed over (7f485a1)**; F-T15-2 company creation open to services (built, held) | **0 d of build left for M1**; remaining is CM's (read the log lines, set enforce, merge G4); F-T15-2 release ~0.5 d, M3 clean-up ~0.5 d |
| **POP** | authorizer (`POP_EA_TENANT_ID`), GL header (`POP_GL_ENGINE_TENANT_ID`), 2 service principals | none: every route and table is Company-scoped, no cross-Company query | 3.5-4 d |
| **IM** | `IM_EA_TENANT_ID`, `IM_GL_ENGINE_TENANT_ID` | pending-adjustments read loads other Companies' rows (filters in route); 4 unscoped `findAll()` without callers; child tables carry no company_id | 7-8 d |
| **SOP** | `SOP_EA_TENANT_ID`, `SOP_GL_ENGINE_TENANT_ID` | **Education Runtime credential reads/writes every order (`SopCompanyScope.All`)**; facility headroom has no Company at all; `GET /api/sales` and returns/complaints lists use `findAll()` and filter in memory; 5 tables without their own company key | ~6.25 d |
| **HR** | `HR_EA_TENANT_ID`, `HR_GL_ENGINE_TENANT_ID` (owner check already `/me`-based) | statement pending | pending |
| **WEB** | none in WEB; the four env-bound services are the limit; one floating widget and a Tenant-level module-chat fallback (fallback removal live-ready) | /me failure sent signed-in people to the new-Tenant wizard (FIXED) | small |

## 4. Requirements

- **R1** Every service decides access for a person from the caller's `/me` Membership whose `companies[]` CONTAINS the Company in the request (exactly one match, else 403/404). No configured Tenant id on the human path.
- **R2** GL calls: people keep sending the Tenant; services may omit it (option A); a sent header must match.
- **R3** Service credentials: endpoint allow-list in GL (G3), and each service scopes its own inbound service credential to what it needs (SOP's Education Runtime credential is not "All").
- **R4** Data layer: every table that is reached only through a parent gets its own Company key where the statement recommends it (SOP five tables + headroom, IM stock child tables), and repositories take the Company so the wall is in the query, not only in the route.
- **R5** Isolation tests in every service prove BOTH walls, table-driven over every route, parameterised "same Tenant" and "different Tenant" so a new route cannot pass one wall and skip the other; plus the first Tenant's snapshot regression (nothing visible to Prodeo Capital's Tenant changes).
- **R6** Env vars `*_EA_TENANT_ID` / `*_GL_ENGINE_TENANT_ID` are removed at the end (M3), never left as a fallback.

## 5. Milestones and order (Tasks, dependency order)

**M0: foundations. DONE or in flight.** GL G0 fail-closed service verifiers (live), G1 isolation matrix (live), G2 service-login matrix (live), G3 allow-list (live, `FISH_SERVICE_ALLOWLIST_MODE=log`), EA E6 isolation tests (live), POP and SOP/IM/WEB statements and addenda (merged).
- M0 remaining: read the G3 log lines after real traffic, set enforce (CM); EA E1 index check in production (needs Femi's read-only script run). Keep log mode until each service has run its RARE paths (HR month-end, leave-accrual remeasure/utilize, returns): each service names them; short windows can miss them.

**M1: a second Tenant can use Sales, Stock, Purchases and Payroll (the UAT tester unblocked).** This is the smallest slice that makes the new owner's day work, and it ships only with the minimum isolation the leaks above demand:
1. GL **G4** (services may omit the header), after enforce.
2. **POP** authorizer per request (R1) + GL header from the authorized Membership; isolation suite (3.5-4 d, the easiest: order first to prove the pattern).
3. **IM** authorizer per request + pending-adjustments query by Company + delete unscoped finders (the authorizer part ~3 d).
4. **SOP** authorizer per request + **Education Runtime credential scoped** (no `All`) + facility headroom given a Company + `findAll()` lists replaced by Company-filtered queries. SOP's wall work is on the critical path for M1 because of the headroom and credential leaks.
5. **HR** authorizer per request (size from HR's statement).
6. **WEB** needs nothing for M1 beyond the live fixes; module-chat fallback removal and widget remount when convenient.
Acceptance for M1: the isolation suites pass (both walls) in POP, IM, SOP, HR, GL; the UAT tester's Tenant `15734cdc-...` can create a customer, record a cash sale, a fixed-fee service sale, receive and issue stock and see none of Tenant `9fa2198b-...`'s data and vice versa; the first Tenant's snapshot is unchanged.

**M2: data-layer hardening before a second REAL customer.** `company_id` on SOP's five tables and IM's stock child tables with backfill/quarantine; repositories take the Company set; static guard "no repository returns rows without a Company argument"; the database-level isolation question (no RLS today; EA's section 6 asks to re-open `docs/Database_Tenant_Isolation_RLS_Scope.md` for GL, EA, HR because a second Tenant in one database reverses its premise); EA reconciliation of `tenant_companies` against GL's Company table (E3 parts 1 and 3).

**M3: clean-up.** Remove the Tenant env vars, delete the unscoped finders, GL F-T15-2 (company creation people-only) once every service has confirmed it never calls it (POP, IM, SOP confirmed; HR pending), update the playbooks.

## 6. Deploy order and rollout safety

1. GL G3 enforce, then G4. Services deploy independently afterwards; each service ships its authorizer change behind its own tests, consumer-first where a wire shape changes.
2. Each service's change is deny-only for anything it cannot map: until a service is switched, a second Tenant simply keeps getting 403 there.
3. A service is switched on for a second Tenant only when its isolation suite is green in CI and I have reviewed it HIGH.
4. First Tenant (`9fa2198b-...`, Femi's) must see no change at each step; each service's statement lists its snapshot regression.

## 7. Open items

| Item | Owner | State |
|---|---|---|
| HR statement | HR | asked three times; plan section 3 row pending |
| Sign-up policy (open vs invite-only) | Femi | undecided; EA's switch on hold |
| GL G3 read the log lines, set enforce | CM | waiting for real service traffic |
| EA E1 unique-index check in production | Femi (read-only script) | pending |
| SOP's Education Runtime credential scope | SOP + ER + CM | design in SOP's statement section 4/6 |
| RLS / database isolation re-open | CM + Femi | M2 |
| Epic 13 (fee billing) built on the multi-Tenant frame | SOP/ER/EA/GL | after M1 foundations |

## 8. Estimates

Per statements: POP 3.5-4 d, IM 7-8 d (authorizer slice ~3 d), SOP ~6.25 d, GL 2-3 d remaining, HR unknown, WEB small. Services run in parallel; with reviews, **M1 is realistically 1-1.5 weeks of calendar time, M2 another week**. These are the sessions' own estimates, not commitments.

## 9. Amendments (v1.1, 2026-10-09, after GL's reading)

- **Header handling (section 6, binding):** a service drops the `X-Tenant-Id` it sends to GL in the SAME release as its per-request authorizer, and only after CM confirms GL G4 is live. Until G4 is live a service that omits the header gets 400, and a service that keeps its env Tenant gets 403 for any Company of another Tenant. G4 is additive, so nothing breaks while it waits.
- **G3 log-mode window:** the lists come from reading each service's GL client; the log-mode cycle is the real confirmation. It stays in log mode until each service has exercised its rare paths; each service names them.
- **GL remaining (all small, after G4):** F-T15-2 release (7168c0a, ~0.5 d, once HR confirms it never calls `POST /tenants/{id}/companies`), M3 playbook/KDoc clean-up (~0.5 d).
- **M2 / RLS for GL: no estimate in this plan.** It depends on whether GL's database role is the table owner (RLS is bypassed unless FORCE is set), the per-request tenant session setting, and Flyway/integration-test interaction. When CM and Femi re-open `docs/Database_Tenant_Isolation_RLS_Scope.md`, GL writes its piece of that scoping first.
- **E3 reconciliation (EA `tenant_companies` vs GL's Companies):** no new GL route. Femi's read-only scripts list both sides (EA: Tenants and their Companies; GL: every Company with its `tenant_id`), and CM compares them. Re-run after each release that registers Companies.
