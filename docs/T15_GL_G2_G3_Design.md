# T15 G2 and G3: service logins stay valid for all Tenants; each limited to an allow-list; Company must belong to the claimed Tenant (GL design)

**Status: 2026-10-09. Design only; nothing built.** Written by the GL session after Femi's D5 decision (relayed by CM): service logins (SOP, POP, IM, HR) stay valid for **all** Tenants; (a) each is limited to an explicit allow-list of GL endpoints (G3); (b) GL verifies on every service call that the Company named in the request belongs to the Tenant claimed in `X-Tenant-Id` (G2), refusing otherwise with the same shape as for people; deny by default. Per-Tenant service logins and token pass-through are not chosen. Context: `docs/T15_GL_Statement.md`.

## 1. G2: the Company must belong to the claimed Tenant, on every service call

**What already exists, and what is new.** Every Company route already runs `resolveTenantForCompany` then `verifyClaimedTenant` for **every caller, service accounts included**: the service-account bypass skips only the EA *membership* lookup (`authorizeTenant`), not these two steps. So the rule is enforced today:

- unknown Company: **404** `not_found`;
- `X-Tenant-Id` that is not the Company's own Tenant: **403**;
- `X-Tenant-Id` absent: **400** `bad_request`.

What is **missing is proof for service callers**: the G1 isolation matrix runs with human tokens only. G2's build is therefore **tests**, not code: the same matrix with each of the four service tokens on every route the credential may call. If a test finds a route that does not run the pair for service callers, that route is fixed.

**Where the check sits and what it trusts.** Unchanged: the two steps at the top of each handler, using **GL's own `companies.tenant_id`** (Company lives in GL; its Tenant is recorded when the Company is created and has no foreign key to EA since V21). I recommend keeping GL's table as the authority and **not** adding an EA call to this check: the check's job is "is this Company in the Tenant the caller claims", which GL's own row answers; an EA call would add an availability dependency without adding security unless GL's row could be wrong. For **people**, EA is consulted (membership lookup) and stays so, fail closed with 503 if EA is unreachable. For **services** there is no EA call on this path, so there is no EA-down failure mode and **nothing to cache**; the only dependency is GL's own database. If CM wants EA's Company-to-Tenant answer as a second source, it needs an EA endpoint (EA's `/me` is per person); say so and I will design it, but I do not recommend it.

**Two decisions I need.** (1) **Missing header: 400 or 403?** CM's wording was "missing/mismatched Tenant = 403". Today a missing header is 400 for everyone and the consumers and the existing tests rely on it. I propose **keeping 400 for a missing header (a malformed request) and 403 for a wrong one**; changing it only for services would make the two callers' contracts differ. (2) None other: unknown Company stays 404.

## 2. G3: an allow-list of GL endpoints per service credential

**Derived from what each service actually calls today**, by reading each repo's GL client (not from memory). The calls to **IM** that POP and SOP make (`/companies/{c}/items/...`, inventory availability) are IM's routes, not GL's, and are excluded.

| Credential | Allowed GL routes |
|---|---|
| **SOP** | `GET /companies/{c}/sales-posting-context`, `GET /companies/{c}/sales-invoices`, `POST /companies/{c}/customer-balances`, `POST /sales/record-sale`, `POST /sales/record-collection`, `POST /sales/record-sales-return` |
| **POP** | `GET /companies/{c}/purchase-posting-context`, `POST /purchasing/record-obligation`, `POST /purchasing/record-payment` |
| **IM** | `GET /companies/{c}/inventory-posting-context`, `POST /inventory/record-receipt`, `POST /inventory/record-issue` |
| **HR** | `GET /companies/{c}/payroll-posting-context`, `POST /journal-entries`, `POST /leave-accruals`, `POST /leave-accruals/{id}/remeasure`, `POST /leave-accruals/{id}/utilize`, `POST /payroll/record-pay-run` |

Everything else is refused to every service credential: all reports and registers, account creation and re-tagging, tax, VAT, bank reconciliation, opening imports, fixed assets, `POST /sales/create-invoice` (no service calls it today), `POST /tenants/{id}/companies` (people-only, F-T15-2), `/me` (human token), `/jurisdictions`. `GET /health` is public and unaffected. **Each service must confirm its list** (a route I missed would be a production 403); the lists come from a read of source, so I would ask SOP, POP, IM and HR to answer in their T15 statements.

**Mechanism.** The credential is identified by which provider authenticated it, so `AuthenticatedCaller` gains a `service` name (SOP, POP, IM, HR; null for people), set once in `installFishJwtAuth`. A single interceptor on `fishAuthenticated`, after authentication and before the handler, checks `(service, method, path)` against one table in code (`ServiceEndpointAllowList`: per service, a list of `METHOD path-template`, templates compiled to regexes with `{x}` matching one path segment). Not on the table: **403** `forbidden_endpoint`, with no information about why beyond that. People are not touched. One table, one place: a new route is unreachable by services until someone adds it, which is the deny-by-default.

**Rollout, because a wrong list is a production outage.** Ship with a mode switch read from `FISH_SERVICE_ALLOWLIST_MODE`: `log` answers normally but logs `WOULD BLOCK <service> <method> <path>` for anything off the list; `enforce` (the default when unset) refuses. CM sets `log` in the task definition for one deploy cycle, reads the logs for would-be blocks, fixes the table, then removes the variable. If CM prefers an immediate hard enforce, the switch is trivial to drop.

## 3. Tests (red first, HIGH review)

1. **Allow-list correctness** (build fails on drift): every table entry is a declared route (read from source, as the G1 inventory does); every declared route is either on at least one list or in an explicit "people only" set, so a **new route cannot be added without classifying it**.
2. **Per credential, per route**: an allowed route reaches the handler (not 403 `forbidden_endpoint`); a route off the list answers 403 for each of the four credentials, and a human token is unaffected.
3. **G2 matrix for services**: for each credential and each of its allowed routes: header absent 400, header of another Tenant 403, unknown Company 404, correct Tenant passes the check; including the routes that carry the Company in the body.
4. **Mutation checks**: dropping the interceptor, and dropping `verifyClaimedTenant` from one allowed route, must each fail the build naming the route.
5. **Log mode**: off-list call answered normally and logged; enforce mode refuses.

## 4. Order and estimate

| Step | What | Effort |
|---|---|---|
| G2 | service-token isolation matrix (tests; code only if a route is found lacking) | 0.5 day |
| G3 | table, `service` on the caller, interceptor, mode switch, tests 1 to 5 | 1.5 days |

Separate branches, G2 first. Release: GL alone; no consumer change if the lists are right. CM: set `FISH_SERVICE_ALLOWLIST_MODE=log` before the G3 deploy, then watch for would-be blocks.

## 5. Needs

- **CM / Femi:** missing header 400 or 403 (section 1); keep GL's `companies` table as the Company-to-Tenant authority (section 1); log-first rollout or hard enforce (section 2).
- **SOP, POP, IM, HR:** confirm the exact GL routes in section 2.
