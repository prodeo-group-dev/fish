# T15: EA's statement (Company -> Tenant resolution, multi-Tenant)

**Status:** 2026-10-09, docs only, written by the EA session at CM's request. Nothing is built or proposed for release before CM's go; the RBAC freeze holds. Facts are read from EA master (`bcc25a6`) and the migrations, not from memory. Items marked **(open)** are not decided here.

**Why now.** Femi decided T15 multi-Tenant comes first: a second Tenant must simply work, and the first Tenant's owner accepts co-tenancy provided its data is never exposed to another Tenant. The trigger was real: a tester onboarded a second Tenant (`15734cdc`, owning Company `7ceb0fa9`, "xyz"), and SOP, IM, POP and HR returned 403 for them because each is bound at deploy time to the first Tenant (`9fa2198b`). The 403 was the services doing what they were built to do.

## 1. What EA guarantees today

| Fact | Where |
|---|---|
| A Company belongs to **one** Tenant. Enforced three ways: `RegisterCompanyUseCase` refuses a Company already linked to another Tenant (answered with fixed wording, `CompanyOwnedByAnotherTenant`, that never reveals the other Tenant); the unique index `ux_tenant_companies_company_id` is the backstop for the race; and there is **no route that removes or moves a Company**, only `addCompany`. | `RegisterCompanyUseCase`; V17; `tenant.kt` |
| **Caveat on the index.** V17 creates it **only if no duplicates exist**; otherwise it logs a warning and skips. Nobody has confirmed from the database that it exists in production. | `V17__company_belongs_to_one_tenant.sql` |
| `GET /me` lists **every ACTIVE Membership** the caller has, one `tenants[]` entry each: `tenantId`, `isOwnerAdmin`, `tenantStatus`, `kybStatus`, and `companies[]` with the caller's `role/accessLevel/grantedModules` per Company. For the Owner Admin, `companies[]` is every Company of the Tenant; for staff, only the Companies they are assigned to. A person in two Tenants gets two entries. | `MeRoutes.kt`, `Dtos.kt` |
| EA already has **one** service-principal Company -> Tenant lookup: `GET /internal/companies/{companyId}/owner-contact` (SOP's pure principal). It resolves the Tenant with `findTenantIdsLinkedToCompany`, answers 404 for an unknown Company and 409 `ambiguous_company_owner` if two Tenants ever claim it, and logs the Company id of every call (never the email). | `OwnerContactRoutes.kt` |
| Service tokens: five EA providers (GL, POP, SOP, IM, HR) resolve a **User with an active Membership** by the token's `email`; they have no bypass in EA (the bypass is in the consumers, per the 2026-09-16 design note). SOP's owner-contact principal is the only pure principal. | `Auth.kt` |
| User identity is **global** (`findByEmail`); Membership is **per Tenant**. KYC lives on the User. One person can already be Owner Admin of one Tenant and staff in another. | `OnboardTenantUseCase`, `InviteStaffMemberUseCase` |
| **Nothing stops a second Tenant.** `POST /tenants` always creates one, and has no idempotency key (a retried POST creates a duplicate). | `TenantRoutes.kt`, `OnboardTenantUseCase` |
| EA's own routes take the Tenant from the **path** and check the caller's Membership in that Tenant, plus Company-in-Tenant where a Company is in the path. EA itself has no deploy-time Tenant binding; the binding is in SOP, POP, IM and HR (`*_EA_TENANT_ID`). | `Auth.kt`, route files |

## 2. How a service resolves Company -> Tenant

### 2.1 A signed-in person (no EA change needed)

`GET /me` is enough. Today a consumer takes the Membership in its one configured Tenant. For multi-Tenant it takes the Membership whose `companies[]` **contains the Company in the URL**, then applies today's level and module checks to that entry. Because a Company belongs to one Tenant, at most one Membership can list it; none means 403 (the same answer as today). This is a **consumer change only**: no wire change, so strict decoding is untouched. Two rules for the consumers:
- Match on the Company id, never on "the first Tenant" or a configured id.
- Refuse when `tenantStatus` is not usable for the act (EA already reports it; each service decides which statuses block writes) **(open: Femi/CM)**.

The configured Tenant id can then be dropped from the human path, which also removes the per-service environment setting that caused this incident.

### 2.2 A service account (no user in the call)

A service call carries no Membership, so it needs either a lookup or a credential that already implies a Tenant. Two real options, and EA's view on each:

- **Lookup (mirrors owner-contact).** `GET /internal/companies/{companyId}/tenant` -> `{companyId, tenantId}`, service principals only, 404 for an unknown Company, 409 if ever ambiguous, Company id logged on every call. EA is the system of record for tenancy, so EA is the right owner. Cost: it discloses a Company's Tenant id to any service credential, and (as GL's options note says) the id is exactly what GL's `X-Tenant-Id` check compares, so alone it turns that header into a formality. It is safe only **with a scope on the credential** (below).
- **Credential implies Tenant (SPUTO D5: one Tenant per credential).** The Tenant comes from the credential, so no lookup is needed to *act*. It does not help a service that **receives** a request naming a Company and must find its Tenant, and it multiplies credentials and Terraform per Tenant, which is CM's cost to weigh.

**EA's recommendation:** build the lookup for the receiving case, and bind each service principal to a **set of Tenants it may act for**, enforced where the act happens (GL for postings; each service for its own routes), taken from the token or a small registry **(open: the credential scope is Femi/CM/GL's decision, T15 as written says one Tenant per credential)**. Without a scope the lookup weakens tenancy; with one it is the missing half. EA's lookup does not enforce the scope: it answers a Company -> Tenant question, and the caller's scope is checked by whoever acts.

**One more source of truth to close.** GL derives the Tenant from **its own Company record** (`resolveTenantForCompany`), and EA derives it from `tenant_companies`. `POST /tenants/{t}/company-registration` takes the `companyId` from the caller and **does not verify that GL agrees** on its Tenant. If the two ever differ, GL and EA give different answers for the same Company. EA proposes one of: EA registration checks GL's Company record belongs to the same Tenant (one service-to-service read), or a reconciliation report both sides run. **(open: GL + EA; who mints the Company id and writes its Tenant in GL needs confirming first.)**

### 2.3 Caching, staleness, revocation

- **Company -> Tenant is effectively immutable** (no move or remove route). A found Tenant can be cached for the life of the process. A **404 must not be cached long** (a Company may be registered a moment later, as the tester's 401 then 201 sequence showed): at most about a minute.
- **Permissions must not be cached across requests.** The human path already calls `/me` on every request; keep it. A revoked Membership disappears from `/me` and the next request gets 403. A service that caches `/me` would silently keep honouring revoked staff, so none should.
- **Suspension.** `tenantStatus` on `/me` shows a suspended Tenant (180-day KYB rule). Whether suspended Tenants are blocked per service today is not uniform; **(open)** decide it once for all services.
- **Unreachable EA** stays fail-closed (503), as today.

## 3. What EA must expose or change

| # | Change | Wire impact | Size | Needs |
|---|---|---|---|---|
| E1 | **Confirm the unique index exists in production** (read-only `\d tenant_companies`); if V17 skipped it, find and resolve the duplicates, then create it. | none | 0.5 day | CM (RDS read) |
| E2 | **`GET /internal/companies/{companyId}/tenant`** (2.2), per-recipient audience, same hygiene as owner-contact (404 / 409 / log the Company id). | new route, additive | 1 day | CM's go; credential scope decision |
| E3 | **Register-time agreement with GL** (2.2) or a reconciliation job. | none on `/me` | 1 day | GL + EA, CM's go |
| E4 | **Add / replace / remove a Company assignment on an existing member** (section 4). | new routes | 2 days | CM's go; after T5a |
| E5 | **Idempotent onboarding**: an idempotency key on `POST /tenants` so a retry cannot create a duplicate Tenant. A stronger rule (refuse a second Tenant per person) is **not** proposed: it would collide with one person owning two Tenants and with the dropped sign-up gate. | additive header | 0.5 day | CM's go |
| E6 | **Isolation tests for co-tenancy** (section 5): a second Tenant in the end-to-end suite asserting every list, count and read route returns only its own Tenant's rows. | none | 1.5 days | none (tests only) |
| none | `/me`, the DTOs, and every consumer mirror: **unchanged**. | none | | |

## 4. The missing route: a Company assignment on an existing member

Today the only way to give a person a role at a Company is the invite, and an invite to an **already-active member returns them unchanged** (`alreadyMember`; a repeat invite's role change is never applied). `PATCH .../memberships/{m}/companies/{c}/modules` only changes the modules of an assignment that already exists. So a person cannot be given access to a second Company later, nor can an assignment be changed or removed, without revoking and re-inviting. (An earlier EA message to WEB, SOP and CM said a re-sent invite re-assigns; that was wrong and is corrected here.) Proposed shape:

- `PUT /tenants/{t}/memberships/{m}/companies/{c}`, body `{role, accessLevel, modules}` now (and `capabilities` once T5a lands): creates the assignment, or **replaces** it. Idempotent.
- `DELETE /tenants/{t}/memberships/{m}/companies/{c}`: removes the assignment. A member with no assignments has no access; the Owner Admin is **not** removable (SPUTO R4/T6).
- Authorization identical to invite and the modules PATCH: `canManageStaffAt(c)`, the Company must be in the Tenant, **never `OWNER_ADMIN`**, a grantor can grant at most what they hold at that Company and **never to themselves** (SPUTO R5/T14).
- It changes who has access, so it is **behind CM's go and T5a**, built once with the capability shape rather than twice.

## 5. Co-tenancy: what must hold, and where EA stands

Femi's condition is that the first Tenant's data is never exposed to another Tenant. For EA specifically:
- **Held at the application layer:** the Tenant comes from the path and is checked against the caller's Membership on every route; Company-in-Tenant is checked wherever a Company is in the path; the eight findings of the 2026-09-14 review (cross-tenant announcement leak and others) are closed and tested.
- **Not held at the database:** no row-level security, no tenant-scoped session. `docs/Database_Tenant_Isolation_RLS_Scope.md` (2026-09-17) recommended holding RLS off because every known bug was closed and the services were effectively single-tenant. **A second Tenant on the same database reverses that premise for GL, EA and HR.** EA asks CM and Femi to re-open that scope before a second customer is real, not after. E6 above is the cheap, immediate part.
- **Company links** (`company_communication_links`) are validated as both Companies in the same Tenant; they must stay that way (no cross-Tenant link), and E6 covers it.
- **Shared things that are global by design:** the User (and its KYC), and the operator surfaces below.

## 6. Operator and Omniview

- Operator routes (`/operator/tenants`, `/operator/support-threads`, platform health) already work across **all** Tenants and are keyed by the Tenant id in the path or listed whole. They need no change for N Tenants, but a list of every Tenant will grow and should be paginated before the second real customer.
- Operator auth is a **named per-operator token**, not a Membership, so an operator is not "a member of every Tenant". Keep it that way: an operator reading Tenant A's support thread must never gain a read of Tenant A's ledger through EA.
- `docs/Omniview_Support_S2_Tenant_Context_Contract.md` already carries the Tenant on each support relay; that stays correct.
- Omniview's own console, when it adds any Company-level view, should resolve the Tenant with E2, not with a configured id.
- With two real Tenants, the operator view will show Femi's own Tenant beside customers'. No special treatment is proposed; it is the same Tenant list.

## 7. Order, and what is waiting on whom

1. **E1** (CM, read-only): confirm the unique index. Nothing else is safe to assume until this is known.
2. Decide the service credential scope (T15 D5): one Tenant, a set, or all, and where it lives. **Femi/CM/GL.**
3. **E6** isolation tests (EA, no go needed; tests only).
4. **E2** + **E3** with GL, behind the scope decision.
5. Consumers (SOP, POP, IM, HR, GL) move from a configured Tenant to "the Membership that lists this Company" on the human path; and to E2 on the service path.
6. **E5**, then **E4** after T5a.

## 8. Open questions

1. **Credential scope** (one Tenant, a set, all) and where it lives; this decides whether E2 is safe.
2. **Who mints the Company id and writes its Tenant in GL**, and whether EA registration should verify it (E3).
3. Which `tenantStatus` values block writes, uniformly across services.
4. Does the unique index exist in production (E1).
5. Re-opening the RLS scope now that a second Tenant exists (section 5).
6. Whether the tester invite into `9fa2198b` is still wanted; it is optional now.

*Verified 2026-10-09 by reading `MeRoutes.kt`, `Dtos.kt`, `OwnerContactRoutes.kt`, `RegisterCompanyUseCase.kt`, `OnboardTenantUseCase.kt`, `InviteStaffMemberUseCase.kt`, `TenantRoutes.kt`, `Auth.kt`, migrations V1/V15/V17/V18, `docs/GL_Tenant_Header_Service_Account_Options.md` and `docs/Service_Account_Identity_And_EA_Membership_Design_Note.md`. Not verified: production data.*
