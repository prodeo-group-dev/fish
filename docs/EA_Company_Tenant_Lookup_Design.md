# EA: the internal Company -> Tenant lookup route (E2) and registration agreement with GL (E3)

**Status:** 2026-10-09, design and test list only; build after CM's go. Written by the EA session at CM's request after Femi's D5 decision: **service logins stay valid for all Tenants, limited to an endpoint allow-list, with GL verifying Company-belongs-to-Tenant on each service call.** Context: `docs/T15_EA_Statement.md` sections 2.2 and 3.

## 1. The route

`GET /api/internal/companies/{companyId}/tenant` answers **only the Tenant id**:

```
200  {"tenantId": "9fa2198b-2a6f-467d-97ac-6f6fbce6a9fd"}
404  {"error": "company_not_found"}        no Tenant owns this Company
409  {"error": "ambiguous_company_owner"}  more than one Tenant claims it (defensive; the unique index should make this impossible)
400  not a UUID          401  not an allowed service principal
```

Nothing else is returned: no Tenant name, status, owner, Tenancy ID or Company name. It mirrors the existing `GET /internal/companies/{id}/owner-contact` (same lookup, `findTenantIdsLinkedToCompany`, same 404 and 409 shapes), which is the precedent for a service-principal route in EA.

## 2. Who may call it (authentication and the allow-list)

- **Pure service principals** for **GL, POP, SOP, IM and HR**: tokens signed for each service's own EA audience (`EA_JWT_SERVICE_AUDIENCE_GL`, `_POP`, `_SOP`, `_IM`, `_HR`, which exist in production per CM's earlier check). Four new named providers `ea-jwt-service-principal-{gl,pop,im,hr}` join the existing `ea-jwt-service-principal-sop`, built the same way: **no User or Membership lookup**, and **no fallback to the human verifier** when that service's audience variable is unset (every request from it is then refused).
- **Human tokens (Owner or staff), operator tokens, no token, a token for any other audience: all 401.** The five older membership-resolving service providers (`ea-jwt-service-*`) are **not** accepted on this route.
- **The allow-list is per route, not per credential.** These five principals may call this one route. `owner-contact` stays **SOP only** (a test pins that GL's principal is refused there). Any further internal route is added to a service's list deliberately.
- **To check (CM):** that GL, POP, IM and HR each have an app client or service login whose tokens carry the EA audience above. SOP already does for owner-contact. Without it those services cannot call this route.

## 3. What callers may cache

- A **200 is immutable**: no route moves or removes a Company, and a unique index (V17) makes it one Tenant per Company. Callers may cache a found Tenant id **for the process lifetime**. EA sends `Cache-Control: private, max-age=3600` on a 200 as a hint.
- **404, 409, 429 and 5xx are never cached beyond about one minute** (a Company may be registered a moment after a first miss, as the tester's 401 then 201 sequence showed). EA sends `Cache-Control: no-store` on them.
- **Pending (E1, CM):** confirm from the production database that `ux_tenant_companies_company_id` exists (V17 skips creating it if duplicates existed). Until confirmed, "immutable" rests on the application check only.

## 4. Abuse and audit

- **Every call logs the Company id and the calling service's name**, never an email or anything else (the owner-contact precedent).
- A **per-service ceiling** (for example 300 a minute) answers `429` identically for everything; callers cache, so real traffic is low.
- An **alarm on a spike of 404s** (CM): that is what probing for Company ids looks like.
- **Disclosure stance, per D5:** any of the five services can learn any Company's Tenant id. That is accepted; the Tenant id is an identifier, not a secret, and each service still checks the caller's Membership or its own scope before acting. GL additionally verifies Company-belongs-to-Tenant on each service call, from its own Company record.

## 5. Tests for E2 (written first, red, when building)

1. Each of the five principals gets `200` with exactly the key `tenantId` for a registered Company; the value is that Company's Tenant.
2. Two Tenants with a Company each: each Company resolves to its own Tenant.
3. An unknown Company: `404 company_not_found` with `Cache-Control: no-store`; a non-UUID: `400`.
4. Refused with `401`: an Owner's token, a staff token, an operator token, no token, a token for an audience that is not one of the five, and (per service) a request when that service's audience is unset (no human-verifier fallback).
5. `owner-contact` still refuses GL's, POP's, IM's and HR's principals (SOP only).
6. A found response carries `Cache-Control: private, max-age=3600`; every non-200 carries `no-store`.
7. The call is logged with the Company id and service name and the log line contains no email.
8. The `409 ambiguous_company_owner` branch, unit-tested with a repository double (the fake and the database both refuse to create the state).
9. The rate ceiling answers the same `429` for any input.
Test support: `TestJwtSupport` gains signers for the GL, POP, IM and HR audiences (it has SOP's).

## 6. E3: EA and GL must agree on a Company's Tenant

**The risk.** GL derives a Company's Tenant from **its own record** (`resolveTenantForCompany`); EA derives it from `tenant_companies`. `POST /tenants/{t}/company-registration` takes the `companyId` from the caller and never checks that GL agrees. If they ever differ, GL and EA give different answers for one Company, and E2's answer would be wrong for GL's posts.
**Proposal, three parts:**
1. **A read-only reconciliation (CM):** compare EA's `tenant_companies` with GL's Company table across the two databases now (it can ride on the owner/approver script at Femi's sitting), and after each release. Any difference is a defect to resolve, not to auto-fix.
2. **A registration-time guard (GL + EA):** GL exposes the same kind of internal read, `GET /internal/companies/{id}/tenant`, for the EA service principal; EA's registration calls it with a service login and refuses with `409 company_registration_rejected` if GL names a different Tenant. If GL is unreachable, registration fails closed (`503`), since the Company already exists in GL when WEB registers it with EA.
3. **Tests (EA side, with a fake GL gateway):** GL agrees: registered; GL names another Tenant: `409` and nothing is linked; GL has no such Company: `409`; GL unreachable: `503` and nothing is linked; the existing registration behaviour is otherwise unchanged.
Part 2 needs GL to build its route (a GL decision) and an EA-to-GL service login (CM); parts 1 and 3 are separable.

## 7. Order

E1 (CM) -> the route and its tests (E2) -> consumers adopt it (POP, IM, SOP, HR resolve the Tenant from the Company instead of a configured Tenant id, with the process-lifetime cache) -> E3 part 2 once GL has its route. E4 (the add-assignment route) and T5a are unchanged and still wait.

## 8. Open

1. CM: do GL, POP, IM and HR already have a token carrying the EA audience, or do they need app clients (section 2)?
2. CM: E1, the unique index in production.
3. GL: will GL build the mirror read for E3 part 2, or is the reconciliation (part 1) enough for now?
4. The per-service rate ceiling value.
