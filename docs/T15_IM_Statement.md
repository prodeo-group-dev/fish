# T15 (multi-Tenant, isolation first): IM's statement

**Owner:** IM session. **Status:** statement and plan, docs only, 2026-10-09. **No code until CM publishes the T15 plan.** **Written against:** IM `origin/master` `0e008b3` (includes the Company-scoped postings, body-id ownership, the Item lock on every write path, `allowedActions`). Every claim was read from that code with `git grep` against master, not from memory. Answers CM's six points for Femi's decision (2026-10-09): derive the Tenant from the Company in each service, so any number of Tenants work; the acceptance test is isolation. **Two walls (Femi):** Tenant against Tenant, and Company against Company inside one Tenant; each business has its own data, consolidation is later. **Deny by default:** an unknown Company or Tenant mapping is 403 or 404, never a fall-back to the old Tenant.

---

## 1. Everything in IM bound to one Tenant or one fixed Company

| Binding | Where | What it does today |
|---|---|---|
| `IM_EA_TENANT_ID` | `Application.kt:152`, passed to `ImMembershipAuthorizer` (`Auth.kt:251`) | **The fixed Tenant.** `resolve` takes `memberships.firstOrNull { it.tenantId == tenantId }`; a caller with no Membership in that one Tenant is refused 403, even if they hold the IM module at a Company of another Tenant. This is the line that makes IM single-Tenant for humans. |
| `IM_GL_ENGINE_TENANT_ID` | `Application.kt:118` into `KtorGlEngineGateway` (`ktor_gl_engine_gateway.kt:31`, header at `:110`) | **The fixed Tenant for GL.** Sent as `X-Tenant-Id` on every GL call (posting context, receipt, issue). A Company under another Tenant is refused by GL (a clean 403, not a misposting). |
| `IM_GL_ENGINE_COMPANY_ID` | **gone from the code** since IM PR #8 | Postings now use the Item's own Company (`Item.entityId`). Only a historical comment in `V8__backfill_entity_id.sql` still names it. Task definitions may still carry the variable; it is not read. |
| GL service account | `IM_GL_ENGINE_SERVICE_ACCOUNT_*`, one Cognito user for all of IM's GL calls (`Application.kt:132-140`) | One outbound identity for every Tenant. Acceptable if GL validates the claimed Tenant against the Company (it does: `X-Tenant-Id does not own the requested resource`), and that check becomes the real wall. |
| Inbound service tokens | `IM_JWT_SERVICE_AUDIENCE_POP` / `_SOP` (`Auth.kt:146,177`) | POP and SOP tokens skip the EA check on every route and are **bound to no Tenant or Company**. In a multi-Tenant IM, a POP or SOP bug (or a stolen token) can name any Company. Today the only brake is `requireOwnedBy` (the record must belong to the Company named in the URL), which does not stop a service naming a valid foreign Company. |
| StoreManager group | `Roles.kt` | Cognito group, **pool-wide**, not per Company or Tenant. It does not cross a wall by itself (approving also needs WRITE at that Company, checked first), but it is an authorization grant that EA cannot see. Moves to EA with T11, held behind T15 per CM. |
| Start-up singletons | `Application.kt` | One `ImMembershipAuthorizer`, one `KtorGlEngineGateway`, one DB pool, one `ExposedIdempotencyKeyRepository` and one `PostgresAdvisoryItemLock`. None keeps per-Tenant state; the idempotency keys and the lock are keyed by Company and Item id, so they are Tenant-safe as they stand. |
| Not tenant-bound (fine) | `IM_JWT_ISSUER` / `_AUDIENCE` / `_JWKS_URL`, `IM_EA_BASE_URL`, `IM_GL_ENGINE_BASE_URL`, `IM_DB_*` | One Cognito pool, one EA, one GL, one database for all Tenants. IM's database stays shared, so isolation is enforced in IM's code and queries; there is no row-level security. |

**The only two places IM reads a Tenant are `IM_EA_TENANT_ID` and `IM_GL_ENGINE_TENANT_ID`.** Everything else already keys on the Company.

## 2. Routes not scoped by a Company in the path

- **Every IM route lives under `/api/companies/{companyId}/...`** (`Application.kt` routing block). The only route outside is `GET /health`, unauthenticated, returning `{"status":"ok"}` and nothing else. No route is un-scoped.
- **Lists** are Company-filtered: Items and Warehouses by `findAllByEntity(companyId)`; Zones and Bins by walking the caller's own Warehouses; **pending adjustments** read **every Company's** pending adjustments and filter in the route by each adjustment's Item (`findAllPendingApproval()` then `itemRepository.findById(...).entityId == companyId`, `AdjustmentAndStockCountRoutes.kt:90`). It does not leak, but it is isolation by a filter, it loads other Tenants' rows into memory, and its cost grows with every Tenant.
- **Id routes** all check ownership before acting (`requireOwnedBy`, 404 like a missing record): Item routes, adjustment approve and reject (through the adjustment's Item), create zone (through the Warehouse), create bin (zone then Warehouse), assign location (Item, and the bin's Warehouse), and the body-supplied bin ids on receipt, issue and both bins of a transfer (IM PR #9).
- **Latent hazards:** four unscoped repository methods exist with **no callers**: `ItemRepository.findAll()`, `WarehouseRepository.findAll()`, `ZoneRepository.findAll()`, `BinRepository.findAll()`. They are traps for the next change; T15 should delete them.
- **What breaks or leaks once two Tenants exist:** (a) a second Tenant's user is refused outright (fail closed, not a leak) because of `IM_EA_TENANT_ID`; (b) a service token can name any Company (see section 1); (c) a user holding Companies A and B (one owner, one Tenant) is separated only by `accessLevelAt(companyId)` plus the ownership checks, which is the Company wall and holds today for every route listed; (d) item, bin and Company ids are UUIDs, so guessing is impractical but the 404-versus-403 behaviour must stay indistinguishable (it is: an unknown or foreign record answers 404, an unknown or foreign Company answers 403).

## 3. Tables lacking a Company key, and queries not filtered by one

Only **`items`** and **`warehouses`** carry `entity_id` (the Company). Everything else is scoped **transitively**:

| Table | Reaches the Company through |
|---|---|
| `item_fifo_layers`, `item_batches`, `goods_receipt_confirmations`, `goods_issue_confirmations`, `inventory_adjustments`, `stock_count_reconciliations`, `replenishment_policies` | `item_id` to `items.entity_id` |
| `zones` | `warehouse_id` to `warehouses.entity_id` |
| `bins` | `zone_id`, then `warehouse_id` |
| `item_location_assignments`, `inventory_balances` | `item_id` and `bin_id` (both must agree; the receipt-into-foreign-bin hole was closed in PR #9) |
| `idempotency_keys` | **has `company_id`** (V9); `goods_issue_confirmations` also carries `company_id` on idempotent rows |

Queries without a Company filter: `findById` on every aggregate (safe only because each route calls `requireOwnedBy` after it), the four unused `findAll()`, and `findAllPendingApproval()`. **Gap:** no database constraint ties a child row to the Company of its parent; a code mistake would not be caught below the application. Recommended defence in depth: add `company_id` to the child tables that act on stock (adjustments, balances, both confirmations, stock counts), backfilled from the parent, with repository methods that take the Company, and drop the unscoped queries.

## 4. Every outbound call, and how the Tenant or Company is passed per request

| Call | Today | Per request under T15 |
|---|---|---|
| EA `GET /me` (authorization, every request) | Forwards the **caller's own token** to the one EA; picks the Membership of the fixed Tenant | `/me` already lists, per Tenant, its Companies. Pick the Membership **whose Company list contains the Company in the URL**; if none contains it, **403**. No lookup route is needed for humans and no Tenant is configured. The Owner-Admin READ floor and module checks stay as they are, evaluated at that Company. |
| GL posting context, receipt, issue | Company = the Item's Company (done); `X-Tenant-Id` = the fixed env Tenant | Tenant = the Tenant that owns the Item's Company. For a **human** call IM already has it from `/me`. For a **POP or SOP service call there is no `/me`**, so it needs the Company-to-Tenant answer from GL option A (omit the header and GL derives and verifies it, IM's preference), GL option B or an EA lookup route (the T15 decision CM publishes). Unknown mapping: refuse (403), make **no** GL call, never fall back to a configured Tenant. |
| GL idempotency key | Derived per Company and key | No change; already Company-scoped. |
| Inbound POP and SOP calls | Company in the URL, blanket bypass | Add the R7 binding: each service credential scoped to the Tenants (or Companies) it may act for, plus an endpoint allow-list (POP: issue; SOP: availability read, issue, receipt, adjustment create). |

## 5. The tests that PROVE isolation (acceptance)

Built first, table-driven over **every route** (about 23) against an in-process IM with two Tenants. Fixtures: Tenant T1 with Companies A and B (one owner holding both, plus a staff member with IM at A only); Tenant T2 with Company C. Each Company has Items, Warehouses, Zones, Bins, location assignments, balances, a pending adjustment, a stock count, a replenishment policy. Real Postgres for the repository-level cases.
1. **Tenant wall:** a T1 user cannot list, read or write C's data under C's path (403) or under A's path (every list contains only A's rows; an id of C's record answers 404 identical to a missing id). The reverse for a T2 user.
2. **Company wall inside one Tenant (same owner holds A and B):** A's Items, Warehouses, Zones, Bins, balances, adjustments, stock counts and policies never appear in B's lists (`/items`, `/warehouses`, `/zones`, `/bins`, `/adjustments/pending`). A **B-scoped call with A's record id** answers 404 for every id-taking route (Item, adjustment approve and reject, stock count, replenishment, levels, location assignments). A staff member with IM at A only gets 403 on B.
3. **Ids in request bodies:** a B-scoped receipt, issue, or transfer naming A's bin id (either bin) answers 404 `bin_not_found` and creates no balance; create zone naming A's warehouse, create bin naming A's zone, assign location with A's bin: all 404.
4. **Choosing the right Membership:** a user with Memberships in T1 and T2 acts in C's path using T2's grant, never T1's (guards the "first Membership" bug class). A Company in no Membership: 403, same body as a nonexistent Company.
5. **Service tokens:** a POP or SOP token naming C with an A Item answers 404; once R7 lands, a token scoped to T1 naming C answers 403.
6. **GL per request:** a posting for B's Item sends B's Tenant (or none under option A), never the old configured one; with no Tenant configured IM still starts; an unknown Company-to-Tenant mapping gives 403 and **zero GL calls**.
7. **Keys and locks:** the same Idempotency-Key in A and B are independent and never replay each other's response; a foreign Item id with the lock busy answers 404, not 409 (no existence probe).
8. **Pending adjustments:** with pending rows in A, B and C, each scope sees only its own; assert the query itself is scoped once the unscoped one is removed.
9. **Responses reveal nothing:** a foreign record and a missing record produce byte-identical status and body.

## 6. IM's estimate and order (days of IM work, CM review on top)

| Step | Work | Days | Depends on |
|---|---|---|---|
| S0 | The isolation suite above, on **current** code first (proves what already holds: the Company wall) | 2 | nothing |
| S1 | Authorizer picks the Membership containing the URL Company; remove `IM_EA_TENANT_ID`; deny when none | 1 | S0; HIGH review (auth) |
| S2 | GL Tenant per request; remove `IM_GL_ENGINE_TENANT_ID`; fail closed on an unknown mapping | 1 | the Company-to-Tenant decision (GL option A, B or EA route) |
| S3 | Defence in depth: `company_id` on the stock child tables (migration V10 plus backfill), Company-taking repository methods, delete the four unused `findAll()` and the unscoped pending query | 2 to 3 | S0 |
| S4 | R7 for inbound POP and SOP: Tenant scope and endpoint allow-list | 1 | D5, EA and GL, CM (secrets) |
| After T15 | T11 (approval via the EA capability) stays on hold behind this | 2 | T15 |

**IM total about 7 to 8 days plus reviews. Order: S0, S1, S3 in parallel with the S2 decision, S2, S4.** Acceptance: the isolation suite green, IM starts with no Tenant variable, and the "unknown mapping" cases refuse. Callers (POP, SOP, WEB) change nothing for S0, S1, S3; S2 and S4 need no caller change except the credentials CM provisions for S4.

## What IM needs from others
- **GL and CM:** the Company-to-Tenant decision (option A is IM's preference) before S2.
- **EA:** confirmation that `/me` lists, per Tenant, every Company the caller may reach, and keeps doing so for an Owner Admin (S1 relies on it).
- **CM:** secrets and Terraform for S4, release order consumers-first, and the T15 plan.
- **POP, SOP:** nothing now; agreement on the allow-lists in S4.
