# GL / POP / IM / SOP Backlog

**Status:** living document — the canonical, dependency-ordered backlog for
work that crosses two or more of GL, POP, IM, SOP (the Purchase-to-Pay /
Inventory / Order-to-Cash cycle and its reversals, with GL as the posting
layer underneath all three). Any of the four sessions may add, reorder, or
close an item here; **do not silently delete another session's item** — mark
it done/superseded with a one-line note instead, the same "never edit
another session's row outright" norm `COORDINATION.md`-style logs already
use in this project.

**Trigger:** direct instruction, 2026-09-28 — "Create and manage a backlog
for all outstanding tasks and order them according to dependencies. There
should be coordination between GL, POP, IM, SOP always in every build."

**Scope note:** this backlog is scoped to the GL/POP/IM/SOP cluster
specifically, per the instruction naming those four services. The wider
FiSH platform has other standing backlogs/parked items (VAT MVP follow-on,
tax-jurisdiction rollout, EA/ERP scope, HR, ER/SchoolAdmissions — see
`FiSH/CLAUDE.md`'s own "Read these first" list and `ER/Principal/docs/The_Principal_Backlog.md`
for that system's own backlog) — not folded in here unless asked, so this
document doesn't silently become the wrong shape for a different question.

**Source material:** almost everything in Wave 1 was audited and scoped
jointly by the POP and IM sessions on 2026-09-28 — see
`docs/Purchase_Inventory_Sales_Cycle_And_Reversals_Scoping.md` (the full
audit) and `docs/POP_IM_Shared_Company_Scoping_Auth_Bug.md` (the auth bug's
own write-up) for the full reasoning behind each item below. This document
is the ordered task list distilled from those; it doesn't repeat their
detail.

---

## How to use this backlog

1. Before starting non-trivial work that touches a GL-crossing posting
   interface (any `Record*UseCase` on GL's side, or the two services either
   side of it), an EA-membership authorizer in any of the four services, or
   anything in the Purchases→Inventory→Sales cycle or its reversals: check
   this file's open items first, and check
   `GL_POP_IM_SOP_Coordination.md`'s Active table for a session already on
   it.
2. Claim an item by adding your session name and a start date in the
   **Owner** column below, and push that claim as its own small commit
   before starting the actual work (mirrors the Coordination log's own
   protocol — see that file).
3. When an item ships, mark it `Done` with the commit/PR/deploy reference,
   don't delete the row — the history of what shipped when is part of why
   this document is useful.
4. Re-sequence waves if a dependency turns out to be wrong — this is a
   working plan, not a fixed spec. Note *why* you re-sequenced.

---

## Wave 0 — live production defects (ship first, no dependencies)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 0.1 | ~~Deploy POP's per-Company auth patch~~ (`PopMembershipAuthorizer`, commit `22b8743`) | POP | — | **Already deployed** (pushed and Jenkins-deployed 2026-09-28 in response to the user's original "push and deploy" instruction, before the later "hold, build the real fix instead" decision was made - confirmed live by CM against the actual ECS task-definition image, `sha-22b874313ff3d2b2d26852d7997c3f54555d2bc6`, stable). There is nothing left to hold - the "don't ship the tactical patch" decision came after it had already shipped. 0.1R still supersedes it as the real fix; this patch stays live in the meantime, since it's strictly safer than what was running before it (see `docs/POP_IM_Shared_Company_Scoping_Auth_Bug.md`). |
| 0.2 | ~~Deploy IM's per-Company auth patch~~ (`ImMembershipAuthorizer`, [PR #6](https://github.com/prodeo-group-dev/fish-inventory-management/pull/6)) | IM | — | **Inadvertently deployed, then reverted - see the incident note below.** Merged to master before the "hold, build the real fix" decision reached this session; IM's Jenkinsfile has no manual gate on master, so it auto-built and auto-deployed to production (task-def `:19`) before the decision could take effect. Confirmed live via a read-only AWS check, then reverted immediately (commit `4bfd384`). CM found the revert push itself hadn't triggered a redeploy (webhook never fired) and manually triggered a corrective build; confirming once live. **Unlike 0.1** (POP's identical-shape patch, left live as "safer than before"), IM's is being pulled back out - flagging this asymmetry for CM/the user to reconcile, not resolving it unilaterally. |
| 0.1R | **Scope real per-Company data isolation for POP and IM** — thread an actual `companyId` through routes and domain queries/storage (mirroring GL's own `authorizeTenant` + companyId-scoped reads), replacing the "check any granted Company" patch entirely once built, not layering on top of it | **POP and IM (each owns fixing their own service, per direct user instruction 2026-09-28) — coordinate on a shared shape rather than diverging independently, the same lesson from this morning's shared bug** | none — supersedes 0.1/0.2 | **Prioritized, direct user instruction 2026-09-28** ("POP should prioritize a fix - scope, plan tasks and order according to dependencies"). **POP's full scope + dependency-ordered task list is now written up in "Wave 0R detail" below** (§0R.0 shared-shape decisions, §0R.1 six-task dependency chain from data backfill through the actual auth-check replacement). Grounded in POP's own `EntityId` field on `Supplier`/`PurchaseOrder` already being persisted (whose own KDoc calls it "the same treatment `CompanyId` gets in the GL Engine") but populated with `crypto.randomUUID()` garbage from WEB today — POP's share of 0.1R is wiring up existing plumbing, not a schema build from scratch. IM's own breakdown for its domain (Item/Warehouse/Bin/etc.) is still pending — three shared-shape decisions in §0R.0 need reconciling between POP and IM before either implements. |
| 0.3 | ~~Confirm whether SOP has the same per-Company auth bug as POP/IM, and fix if so~~ | SOP | — | **Deployed and confirmed live.** Confirmed a different bug than POP/IM (SOP never had the "hardcoded companyId" shape at all - its per-Company checks already take the request's own `companyId`), traced to the same `accessLevelAt()` intrinsic-floor root cause as 0.4. Fixed in [SOP PR #5](https://github.com/prodeo-group-dev/fish-sales-order-processing/pull/5), user approved all of Wave 0 on 2026-09-28, merged (`a37cf03`), deployed, and confirmed live by CM against the actual ECS task-definition image - service stable, old task fully drained. |
| 0.4 | ~~Merge + deploy GL's `accessLevelAt` intrinsic-floor fix~~ (same root cause as 0.3, found independently while diagnosing the live "Couldn't load sales" bug for Education Runtime) | GL | — | **Deployed and confirmed live.** Fixed in [GL PR #53](https://github.com/prodeo-group-dev/fish-fish-gl-engine/pull/53), user-approved, merged, deployed, and confirmed live by CM (`sha-d0819bb`, matches master HEAD, service stable). POP/IM never needed this fix - their patches sidestep it by checking "any Company," never calling `accessLevelAt` with an absent `companyId`. **Surfaced a real, independent bug along the way**: GL's `Jenkinsfile` Deploy stage had never actually worked via Jenkins - it referenced `task-definition.json` in a `jq` step with no preceding command that ever created the file, so every prior Jenkins-triggered master deploy for GL had been silently failing (`No such file or directory`) and every GL deploy this whole session had actually happened via manual `aws ecs register-task-definition`. Fixed (`d0819bb`) and this exact deploy is the first real proof the automated path now works end to end. |

| ~~0.5~~ | ~~SOP's `Customer` routes are unscoped despite `Customer.entityId` being real and populated~~ - `GET /customers` (`authorizeSopForRead()`, tenant-wide, `customerRepository.findAll()` - no `findAllByEntity` method exists at all) and `POST /customers` (`authorizeSopForWrite()`, tenant-wide - any caller can create a Customer tagged with any `entityId`) both leak/allow-write across every Company in the Tenant. `GET /customers-with-balances` takes `companyId` as a query param but only checks tenant-wide read access, never that specific Company - a caller can query any Company's balances by just naming it in the query string. | SOP | — | **Superseded by 0.6 (2026-09-29)** - the underlying gap (no real per-Company scoping on `Customer`) is real, but the original characterization ("field already exists and is already populated correctly - there's no domain-modeling question to resolve first, just missing plumbing") was wrong on both counts. Kept struck through rather than deleted per this doc's own "never silently delete another session's item" rule. |
| 0.6 | **Correction to 0.5, 2026-09-29 (SOP session):** `Customer.entityId` is NOT "real and populated" the way POP's `Supplier.entityId` is post-backfill - checked WEB directly (`sopCustomers.ts`'s `generateEntityId()`, called from `SopCustomersTab.tsx`/`SalesTab.tsx`) and it's `crypto.randomUUID()` garbage on every create, the exact same pre-0.1R stopgap POP's own `Supplier`/`PurchaseOrder.entityId` had before that work started - not "already correctly populated" as 0.5 first characterized. A naive fix (add `findAllByEntity`, authorize `GET`/`POST /customers` against the caller's own `entityId`) would silently break the Customers list for everyone, since every `Customer` has a random, never-matching `entityId` - not a real fix, just a differently-broken one. There's also a real, unresolved *conceptual* question underneath, separate from the data-quality one: `EntityId`'s own KDoc calls it "which Prodeo/Purse legal entity is conducting the sale" (`NFR-SO03`) - Group-level (Purse vs. Scrip vs. Osusu vs. the B2B SaaS offering), not necessarily the same grain as a single GL `Company` (recall Purse alone is 1 Tenant/4 Companies). `OrdinarySaleRoutes.kt`'s own `POST /sales` already authorizes against a *separate* `companyId` body field, distinct from `entityId` - suggesting `Company`-level scoping (if that's really what `Customer` needs) should key off a `companyId` `Customer` doesn't have at all, not off `entityId`. So this is closer in shape to `ReturnRequest`/`CreditNote`'s "no Company concept modeled, needs a real decision" situation than to POP's "existing plumbing just needs wiring" 0.1R pattern. **Resolved by direct user decision, 2026-09-29: `EntityId` = `CompanyId`, same grain as POP/IM.** Consistent with their already-shipped 0.1R call - SOP's own `NFR-SO03` uses the identical generic boilerplate POP's/IM's requirements docs do, with no SOP-specific resolution note; the more specific "Purse/Scrip/Osusu" wording traced back to a single Claude-authored code comment from the original 2026-08-20 "Build Customer aggregate" commit, not a separate instruction naming those ventures. Unblocked - 0.7 below is the actual fix, same shape as POP's 0.1R. | SOP + POP/IM (shared-shape decision, same as 0.1R's §0R.0) + user (whether `EntityId` and `CompanyId` are meant to be the same concept at all) | 0.1R's shared-shape decisions may resolve this too | **Resolved 2026-09-29 - see 0.7** |
| 0.7 | **Build real per-Company scoping for SOP's `Customer`**, now that 0.6 is resolved: (1) rename/repurpose `EntityId` to genuinely carry `CompanyId` values - the type can likely stay, only its meaning and provenance change; (2) fix WEB (`sopCustomers.ts`'s `generateEntityId()`, called from `SopCustomersTab.tsx`/`SalesTab.tsx`) to send the real authenticated `companyId` instead of `crypto.randomUUID()`; (3) add `CustomerRepository.findAllByEntity`/equivalent; (4) add `authorizeSopForReadAt(companyId)` (doesn't exist yet - only `ForWriteAt` does) and scope `GET /customers`/`POST /customers`/`GET /customers-with-balances` to it. Existing `Customer` rows have garbage `entityId`s and need a backfill/migration decision, same shape as POP's own backfill task in its 0R.1 breakdown. | SOP (coordinate shared shape with POP/IM per 0.1R's §0R.0, since this is the same underlying pattern) | 0.6 (resolved) | Not started |
| 0.8 | ~~**EA response DTO drift crashed every human-authenticated request, platform-wide**~~ - EA added `userId` to `GET /me`'s response 2026-09-28 (`MeRoutes.kt` commit `cf1cef69`, incidental to an unrelated SchoolAdmissions change) and `schoolId` to `CompanySummaryDto` 2026-09-27 - neither field was declared in GL's/POP's/IM's/SOP's own hand-mirrored `EaMyProfileResponseDto`/`EaCompanySummaryDto` copies, and kotlinx.serialization's strict default decoding throws on any undeclared field. Surfaced as a live production 500 on `GET /api/sales` (SOP, caught by WEB ~03:32 2026-09-29), then recurred a second time on `schoolId` specifically (~06:40, also caught by WEB) after the first fix only covered `userId`. | GL + POP + IM + SOP (each patched its own DTO independently, converged on the same fix shape) | none | **All eight gaps (userId × 4 services, schoolId × 4 services) fixed, merged, and confirmed live via CM against the real ECS task-definition image on every service**: GL `sha-d0819bb`→`ac11758` (also re-verified field-for-field, found `schoolId` there too before it could crash), POP `39473ef` (found both fields proactively before either crashed in production), IM `5f223a5` (found both, including flagging the pattern to POP first), SOP `7824bab`+`bc274eb` (found `userId` first via the live crash, `schoolId` second via re-verification, same diligence GL applied). **Platform-wide policy decided and written down** (`CLAUDE.md`, "EA response DTOs: strict decoding, no `ignoreUnknownKeys`", direct instruction: *"This is a Multi-Tenanted Cloud-Native Project. Security is paramount and sacrosanct. There should not be a case where there exists unknown keys being processed."*) - declare every field EA's `/me` actually sends, never loosen the EA-calling client to `ignoreUnknownKeys = true`, even though GL briefly carried that config (2026-09-21) as a resilience trade-off. Explicitly scoped to *this* payload only, not a blanket rule: SOP's own `imHttpClient` (`fetchItemAvailability`'s deliberately partial stock-check DTO) keeps `ignoreUnknownKeys = true` - confirmed correct by direct user decision after CM raised it as a possible inconsistency - since it's a business-data partial read, not an access-control decision. |

These are independent of each other (different services, different repos)
but share one root cause and one open user decision (whether/when to
deploy) — listed together so that decision gets made once, not twice.

---

## Wave 0R detail — POP's own task breakdown for real per-Company data isolation

**Priority, direct user instruction 2026-09-28** (relayed via GL): "POP should prioritize a fix (Scope, Plan Task and Order tasks according to dependencies)." This is that breakdown for POP's own side. IM co-owns 0.1R and should produce the equivalent breakdown for its own domain (Item/Warehouse/Bin/etc.) separately - the two reconcile on the three shared-shape decisions in §0R.0 before either implements, not on every internal detail.

Confirmed by reading the code directly (not assumed): `PurchaseOrderRepository`/`SupplierRepository` are small interfaces (`save`/`findById`/`findByStatuses`/`findAll` - four methods total between them); ~25 call sites across three route files call `authorizePopForRead`/`authorizePopForWrite`, all the same one-line `if (!call.authorizePop...()) return@get` shape. Real, bounded scope - not hundreds of call sites.

### 0R.0 — Shared-shape decisions (reconcile with IM before implementing either side)

| # | Decision | Recommendation | Status |
|---|---|---|---|
| 0R.0.1 | Does `EntityId` (POP) / IM's equivalent, if any, become literally the same UUID space as GL's `CompanyId` - i.e., WEB sends the real Company id it already tracks (`selectedCompanyId`, from the org-picker fixed 2026-09-18), not a locally-generated id? | **Confirmed, both services agree: yes.** `EntityId`'s own KDoc already frames it this way; IM independently confirmed the identical pattern on its own side (`Item.entityId`/`Warehouse.entityId`, both real persisted columns, `findAllByEntity()` already implemented and correct on both repositories - just never called from any route). Same root stopgap on IM's side too: `generateEntityId()` in `api/im.ts` is the same bare `crypto.randomUUID()`. | **Decided** |
| 0R.0.2 | How does a per-request companyId reach POP's/IM's routes: GL's own `/companies/{companyId}/...` path convention, or a header/query param? | **Decided: path-based, matching GL's own convention.** IM leans this way already (fewer routes, ~15, lower restructuring cost) and explicitly deferred to whichever keeps POP/IM consistent with each other over either service's own preference. Converging on GL's established shape rather than inventing a second convention: predictable API shape across the whole platform outweighs POP's larger one-time rewrite cost (~25 routes) - this is meant to be the real fix, not another shortcut. | **Decided** |
| 0R.0.3 | Does `PopMembershipAuthorizer`/IM's equivalent revert to GL's exact shape (`accessLevelAt(realCompanyId).atLeast(min) && module in grantedModulesAt(realCompanyId)`, one specific company, not "any") once a real per-request companyId exists? | Yes - this is the whole point of 0.1R; the "any Company" patch (0.1/0.2) was explicitly a stopgap for company-blind domain models, not the end state. Both services agree. | **Decided** |

**All three shared-shape decisions closed 2026-09-28.** IM independently confirmed identical findings on its own side rather than taking POP's read at face value - both services' 0.1R work is "wire up existing plumbing," not a schema build from scratch. IM writing its own Wave-0R-detail section next, same shape as POP's below.

**Operational note (2026-09-28, IM):** IM's own "check any Company" patch (PR #6) was merged and Jenkins auto-deployed it before the user's hold decision reached that session - no gate on master. IM has since pushed a revert (confirmed via read-only AWS check) and flagged it to CM under the new push-coordination convention. Relevant to POP too: merging a PR to POP's master carries the identical no-gate auto-deploy risk - worth remembering once 0.1R's actual implementation PRs are ready, so a partial cross-service change doesn't go live mid-rollout.

### 0R.1 — POP task list, in dependency order

| # | Task | Depends on | Notes |
|---|---|---|---|
| 0R.1.1 | ~~Backfill migration: set every existing `suppliers`/`purchase_orders` row's `entity_id` to Prodeo's real original Company id~~ | 0R.0.1 decided | **Done.** [PR #8](https://github.com/prodeo-group-dev/fish-purchase-order-processing/pull/8), merged+deployed 2026-09-28, confirmed live by CM against the actual ECS task-definition image (`sha-39bf3b2`, service stable 1/1). Company id (`2ee7984b-1817-4148-ad04-653df9de724a`) sourced via CM's read-only task-definition lookup. |
| 0R.1.2 | ~~WEB: stop calling `generateEntityId()` (`crypto.randomUUID()`); send the real `selectedCompanyId` on `POST /purchase-orders`/`POST /suppliers` instead~~ | 0R.0.1 decided | **Done.** [WEB PR #11](https://github.com/prodeo-group-dev/fish-gl-web/pull/11), reviewed and merged by CM (`1302f51`) and deployed via `deploy.sh` - live on CloudFront, confirmed independently (PR state MERGED, same SHA CM reported). Threads `selectedCompanyId` through `PopTab`→`PurchasesTab`→`CreatePurchaseOrderTab` and `PopTab`→`SupplierSchedule`, removed the dead `generateEntityId()`. |
| 0R.1.3 | ~~WEB: rewrite every POP call to the new `/companies/{companyId}/...` path shape~~ | 0R.0.2 decided | **Done, merged and deployed.** [WEB PR #12](https://github.com/prodeo-group-dev/fish-gl-web/pull/12) (`b862dc3`), part of the coordinated three-way cutover below. |
| 0R.1.4 | ~~`PurchaseOrderRepository`/`SupplierRepository`: add a `companyId` parameter to `findByStatuses`/`findAll`, filtering in the Exposed implementation (`WHERE entity_id = ?`); add a company check to `findById`'s callers (return "not found" for a wrong-company id, matching GL's own `RecordSalesReturnUseCase`-style pattern, not a distinct "forbidden")~~ | 0R.1.1 (real data to filter), 0R.0.1 | **Done, merged and deployed** - see the coordinated cutover note under 0R.1.6 below. |
| 0R.1.5 | ~~Routes: restructure all ~25 route registrations under `/companies/{companyId}/...` (mirroring GL's own path-parsing pattern - `call.parameters["companyId"]` -> `parseUuid` -> `CompanyId`), threading the real companyId through every `authorizePopForRead`/`Write` call site and into the use-case calls that now need it (0R.1.4)~~ | 0R.1.3, 0R.1.4 | **Done, merged and deployed** - see the coordinated cutover note under 0R.1.6 below. |
| 0R.1.7 | ~~**Object-level per-Company write-action isolation**~~ | 0R.1.5 | **Done, merged and deployed** - see the coordinated cutover note under 0R.1.6 below. |
| 0R.1.6 | ~~`PopMembershipAuthorizer`: take the real per-request companyId, check grants at that specific company (0R.0.3) - replaces the 0.1 "any Company" patch entirely, not layered on top~~ | 0R.1.5, 0R.1.7 | **Done, merged and deployed, 2026-09-30.** Built in direct response to a CRITICAL finding CM caught reviewing this branch against IM's PR #7 before the original coordinated-merge attempt: `PopMembershipAuthorizer` was still checking "granted POP at ANY Company" even after 0R.1.4/0R.1.5/0R.1.7 made routes/data genuinely Company-scoped - a caller with access at Company A could have read/written Company B's real data by changing the URL's `companyId`. Fixed: `resolve()` now checks the Membership's grant at the real per-request companyId specifically. **Coordinated three-way cutover, fast-tracked ahead of SOP's own equivalent work during a SEV-1 cross-tenant data-exposure investigation** (POP's *live pre-cutover* code - the 0.1 "any Company" patch plus genuinely unscoped data - was flagged as a plausible root cause): [POP PR #10](https://github.com/prodeo-group-dev/fish-purchase-order-processing/pull/10) (`cf39c34`) + a same-day follow-up fixing a stale integration test CM caught in CI (`7aad5cd`), [WEB PR #12](https://github.com/prodeo-group-dev/fish-gl-web/pull/12) (`b862dc3`), [IM PR #7](https://github.com/prodeo-group-dev/fish-inventory-management/pull/7) (`038e53b`) - all merged and deployed together (POP: task-def `:21`, image `sha-7aad5cd`, confirmed live and stable by CM). 220 tests green on POP's side. **All of Wave 0R.1 (0R.1.1-0R.1.7) is now live in production.** |

Nothing here touches GL - confirmed in the original audit that every GL-side posting primitive POP calls is already fully generic and company-agnostic at the caller's discretion.

### 0R.1.7 detail — object-level per-Company write-action isolation, dependency-ordered

**Trigger:** direct instruction, 2026-09-29 - the write-action gap flagged in 0R.1.4/0R.1.5's own commit message ("deliberately NOT covered... tracked separately") should be "Scoped, Planned, Tasked, and then Dependency Ordered," not just left as a one-line flag.

**Scope, confirmed by reading the code directly:** every one of these routes already parses the PurchaseOrder's `{id}` off its own path (`call.parsePurchaseOrderId()`), whether or not the route goes on to use it - the nested sub-resource routes (`{proposalId}`/`{reportId}`/`{returnId}`) all sit under `/purchase-orders/{id}/...`, so `{id}` is always available to check against, never something that needs threading in from elsewhere. This makes the fix a **route-level pre-check**, not a use-case signature change: fetch the PurchaseOrder by the path's own `{id}`, compare `entityId` to the path's `companyId`, 404 on mismatch, *before* calling the use case - mirroring exactly what 0R.1.4 already did for `GET /purchase-orders/{id}`, just applied to every write route instead of the one read route. No use case's `execute()` signature needs to change; the check happens one layer up, at the route.

**One structural gap this surfaces**: `purchaseOrderFulfillmentRoutes()` currently has no `PurchaseOrderRepository` parameter at all (it only ever reaches PurchaseOrders indirectly through use cases) - unlike `purchaseOrderRoutes()`, which already takes one. Needs adding, threaded from `Application.kt` (already a local `val` in both `productionModule()` and every test `Fixture`, so no new dependency to construct).

| # | Task | Depends on | Notes |
|---|---|---|---|
| 0R.1.7.1 | Add a `purchaseOrderRepository: PurchaseOrderRepository` parameter to `purchaseOrderFulfillmentRoutes()`, wired from `Application.kt`/`popModule()` | none | Wiring only, no behavior change - safe to land on its own. |
| 0R.1.7.2 | Add a shared `ApplicationCall.verifyPurchaseOrderCompany(id, companyId, purchaseOrderRepository): Boolean` helper to `RouteHelpers.kt` - fetch by `id`, 404 (`purchase_order_not_found`) if missing or `entityId != companyId`, else `true`. Mirrors `GET /purchase-orders/{id}`'s own inline check (0R.1.4), factored out since it's about to be reused ~18 times. | none (can be written alongside 0R.1.7.1) | Pure addition, no existing route changes yet. |
| 0R.1.7.3 | Apply the helper to all 5 write routes in `PurchaseOrderRoutes.kt`: `submit-for-approval`, `approve`, `send`, `cancel`, `amend` | 0R.1.7.2 | Each route already parses `id` - just add `if (!call.verifyPurchaseOrderCompany(id, companyId, purchaseOrderRepository)) return@post` right after. |
| 0R.1.7.4 | Apply the helper to all 13 write routes in `PurchaseOrderFulfillmentRoutes.kt`: negotiation `accept`/`reject`, discrepancy-report raise (internal route only, not the supplier-portal one - see below) `/acknowledge`/`/resolve`, `receive-line`, `match`, `pay`, returns `initiate`/`approve`/`reject`/`dispatch`/`credit-note` | 0R.1.7.1 (repository now available in this file), 0R.1.7.2 | The bulk of the work, purely mechanical once 0R.1.7.1/0R.1.7.2 land - every one of these routes already parses `id` today (some currently discard it), so this is "stop discarding it, check it" at each site. |
| 0R.1.7.5 | Regression tests: one E2E test per distinct code shape (a route acting directly on `{id}`, and a route acting on a nested `{proposalId}`/`{reportId}`/`{returnId}` via the PO's own `{id}`) proving a cross-Company PurchaseOrder id is rejected with 404 - not one test per route (18 would be pure duplication of the same assertion) | 0R.1.7.3, 0R.1.7.4 | Mirrors the E2E test 0R.1.4/0R.1.5 already added for `GET /purchase-orders/{id}`. |

**Explicitly NOT in scope, flagged rather than silently folded in**: the supplier-portal routes (`AttachWaybillUseCase`, and the portal's own calls into `RaiseNegotiationProposalUseCase`/`RaiseDiscrepancyReportUseCase`) need no change here - they're token-scoped (`OrderAccessToken.purchaseOrderId`), already narrowed to one specific PurchaseOrder by the secret itself, with no `companyId` path context to check against in the first place.

**A separate, narrower gap noticed while scoping this, parked rather than fixed here**: none of the `returns`/`negotiation-proposals`/`discrepancy-reports` sub-resource routes currently verify that `{returnId}`/`{proposalId}`/`{reportId}` actually belongs to the `{id}` PurchaseOrder named in the same path - only that `{id}` itself exists (and, once 0R.1.7 ships, belongs to the caller's Company). A caller could reference a real `returnId` alongside an unrelated-but-valid `{id}`. This is orthogonal to Company isolation (it would exist even in a genuinely single-Company deployment) and isn't solved by anything in 0R.1.7 - noted here so it isn't mistaken for closed.

---

## Wave 0R detail — IM's own task breakdown for real per-Company data isolation

**Ownership boundary, direct user instruction 2026-09-28**: "IM must own inventory issues, POP must own Purchase and Returns Outwards issues." This section is IM's own domain only - `Item`/`Warehouse`/`Zone`/`Bin`/`InventoryBalance` state and the goods-receipt/goods-issue crossing points. Anything that's fundamentally a Purchase or Returns-Outwards concern (even one that touches inventory data as a side effect, e.g. a supplier return dispatching a goods issue) stays POP's to own end-to-end - not duplicated or re-scoped here.

Confirmed by reading the code directly: IM's version of POP's `EntityId` finding (§0R.0.1) is even further along than POP's own. `Item.entityId`/`Warehouse.entityId` are both real persisted columns (`entity_id` on `ItemsTable`/`WarehousesTable`), and `ItemRepository.findAllByEntity()`/`WarehouseRepository.findAllByEntity()` are already implemented correctly - just never called from any route (every route calls the unscoped `findAll()` instead, per `ItemRepository`'s own KDoc: *"Unscoped listing (2026-09-01, 'Wire WEB to IM') - EntityId has no aggregate/picker anywhere yet... so a real 'every item' list needs this rather than findAllByEntity"*). Same root stopgap as POP's: `generateEntityId()` in WEB's `api/im.ts` is a bare `crypto.randomUUID()`, and `POST /bins` doesn't even take one client-side (server defaults to a fresh random UUID). `Zone`/`Bin` don't carry their own `entityId` at all - they scope transitively through `Warehouse` (`findAllByWarehouse`/`findAllByZone`), matching WEB's own nested Warehouse→Zone→Bin drill-down UI (rebuilt 2026-09-12) rather than needing a new direct entity-scoped query. `GoodsReceiptConfirmation`/`GoodsIssueConfirmation`/`ItemLocationAssignment`/`InventoryBalance`/`StockCountReconciliation` all scope transitively through `Item`/`Bin` (`findAllByItem`/`findAllByBin`, no top-level unscoped listing) - safe once `Item` itself is company-scoped, since every caller reaches them via an already-scoped `Item`/`Bin` first.

### 0R.2 — IM task list, in dependency order

| # | Task | Depends on | Notes |
|---|---|---|---|
| 0R.2.1 | ~~Backfill migration: set every existing `items`/`warehouses` row's `entity_id` to Prodeo's real original Company id (the one `IM_GL_ENGINE_COMPANY_ID` already names)~~ | §0R.0.1 decided | **Assumption fully confirmed on both tables, 2026-09-28 (CM ran both queries against `im_production`)**: `items` - 10 rows, 10 distinct `entity_id` values, every count 1. `warehouses` - 1 row, 1 distinct value, count 1. Same clean "fresh random UUID per row, nothing ever grouped or read it back" pattern on both, no clustering, nothing intentional-looking. Safe to blanket-overwrite. Migration written (IM, not yet handed to CM to push) - see change log. |
| 0R.2.2 | WEB: stop calling `generateEntityId()`; send the real `selectedCompanyId` on `POST /items`/`POST /warehouses`/`POST /zones`/`POST /bins` instead | §0R.0.1 decided | Mirrors POP's 0R.1.2. Coordinate the cutover with 0R.2.1 the same way POP is - no window where new rows get a real id while old rows still have garbage. |
| 0R.2.3 | WEB: rewrite every IM call to the `/companies/{companyId}/...` path shape (`GET /items`, `GET /warehouses`, `GET /zones`, `GET /bins`, every action route) | §0R.0.2 decided | Smaller surface than POP's - IM has ~15 routes total, not ~25. |
| 0R.2.4 | ~~`ItemRepository`/`WarehouseRepository`: switch every route's call site from `findAll()` to the already-implemented `findAllByEntity(companyId)`; add a company check to `findById`'s callers (404, not 403, for a wrong-company id - matching GL's own pattern, per §0R.0.3's reasoning)~~ | 0R.2.1 (real data to filter), §0R.0.1 | **Code complete, 2026-09-28 - see [PR #7](https://github.com/prodeo-group-dev/fish-inventory-management/pull/7).** `Zone`/`Bin` (no `entityId` of their own) compose via walking the caller's own Warehouses through Zones, matching WEB's nested drill-down UI. **Newly discovered while building this**: `GET /adjustments/pending` has the identical gap (`InventoryAdjustment` carries no `entityId`, only `itemId`) - not called out in the original task list, filtered in the application layer (check each pending adjustment's Item against the caller's company) rather than left open. |
| 0R.2.5 | ~~Routes: restructure all ~15 route registrations under `/companies/{companyId}/...`, threading the real companyId through every `authorizeImForRead`/`Write` call site and into the use-case calls that now need it (0R.2.4)~~ | 0R.2.3, 0R.2.4 | **Code complete, PR #7.** Built ahead of 0R.2.3 (WEB's own path cutover) rather than strictly waiting on it - nothing stops writing IM's half first, only deploying it before WEB's ready. |
| 0R.2.6 | ~~`ImMembershipAuthorizer`: take the real per-request companyId, check grants at that specific company (§0R.0.3) - replaces the 0.2 "any Company" patch entirely (already reverted out of production, see 0.2's status above)~~ | 0R.2.5 (routes must supply a real companyId first) | **Code complete, PR #7.** `resolve()` now takes `companyId: String` per call - `accessLevelAt(companyId).atLeast(min) && "IM" in grantedModulesAt(companyId)`, the same shape GL's `authorizeTenant` already uses. |

**PR #7 status**: all of IM's own 0R.2.4-0R.2.6 code is written, tested (227 unit tests + integration tests against a fresh ephemeral Postgres, all passing), and pushed to `feature/im-real-per-company-scoping` - **deliberately not merged to master**. `CreateItemRequestDto`/`CreateWarehouseRequestDto`'s `entityId` fields are kept (accepted-but-ignored, companyId now comes from the URL path) so any WEB caller still on the old contract doesn't break mid-rollout - but the *path* restructuring itself (0R.2.3, still WEB's own unstarted task) is a hard break: every existing WEB call to a flat `/api/items` etc. URL will 404 once this merges, since the routes no longer exist at the old paths. Holding for WEB's 0R.2.2/0R.2.3 and CM's go-ahead to merge/deploy, per the dependency ordering above and the "only CM pushes to master" convention.

Nothing here touches GL or POP - confirmed in the original audit that `RecordInventoryReceiptUseCase`/`RecordInventoryIssueUseCase` on GL's side are already fully generic, and the service-account calls POP/SOP make into IM (goods receipt/issue) permanently bypass the EA-membership check by architectural design (`VerifiedIdentity.isServiceAccount`'s own KDoc) - this per-Company work only affects IM's human-facing routes, not the module-to-module crossings.

---

## Wave 1 — small follow-ups from Wave 0 (style/consistency, not correctness)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 1.1 | Converge POP's inline `.any {}` auth check and IM's named `CallerMembership.hasModuleGrantedAnywhere()` helper on one shape — and decide whether it belongs on each service's own copy of the EA-membership code, or gets hoisted somewhere shared | GL/POP/IM/SOP (joint decision) | 0.1, 0.2 shipped | Open question, not picked — flagged in the audit's §7.5 |

Not blocking — both services' fixes are already correct independently.

---

## Wave 2 — IM's receipt-side generalization

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 2.1 | Generalize `IM/RecordGoodsReceiptUseCase`: make `contraAccountId` caller-overridable (default to AP control account for existing PO-receipt callers, mirroring `RecordGoodsIssueUseCase`'s 2026-09-03 precedent exactly) and make the PO-specific `purchaseOrderReference` field generic (or add a parallel non-PO field) | IM | none (can start any time) | Not started — scoped in the audit §4 |

No GL change needed — `RecordInventoryReceiptUseCase` on GL's side is
already fully generic (confirmed by reading it directly). This is entirely
IM's own application-layer file.

---

## Wave 3 — Returns Inwards inventory-value posting

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 3.1 | Add the SOP→IM crossing for Returns Inwards: a new `ImGateway.recordGoodsReceipt`-equivalent call from SOP, mirroring the existing `ImGateway.recordGoodsIssue` call SOP already has elsewhere, invoked after `InspectReturnedGoodsUseCase` determines a `Resaleable` disposition | SOP (calling IM's new interface from 2.1) | 2.1 | Not started |

This closes the one real accounting-correctness gap in the reversal flows:
today a Resaleable Returns-Inwards credit note posts the AR side
(`RecordSalesReturnUseCase`) but not the inventory-value side
(`Dr Inventory / Cr Sales Returns`).

---

## Wave 4 — Returns Inwards disposition decisions + build

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 4.1 | **Decide**: Scrap disposition posting — reuse `InventoryAdjustment`'s existing `DAMAGE` reason (no new IM mechanism), or does it need its own write-off path traceable back to the originating `ReturnRequest`? | IM + SOP (joint decision) | none — can be decided in parallel with Wave 2/3 | Open question, not picked (audit §7.1) |
| 4.2 | **Decide**: Repairable disposition — does "quarantine" need a real IM location-state concept (possibly reusing the existing `LocationState`/bins mechanism as-is), or is this genuinely unbuilt inventory-state modeling? | IM | none | Open question, not investigated in depth (audit §7.2) |
| 4.3 | Build the Scrap disposition posting | IM/SOP | 4.1 decided; ideally after 3.1 ships so Resaleable is the proven pattern | Not started |
| 4.4 | Build the Repairable disposition posting | IM/SOP | 4.2 decided; ideally after 3.1 ships | Not started |

---

## Wave 5 — lower priority, no dependency relationship to the above

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 5.1 | RMA document generation (FR-RA2, Returns Inwards spec) | SOP | none | Not built (per spec's own build-status table) |
| 5.2 | Returns reporting/analytics (FR-RE1/FR-RE2) | SOP | none | Not built (per spec's own build-status table) |

Can run in parallel with any other wave, or whenever prioritized — genuinely
separable from the accounting-correctness work above.

---

## Backlog, not yet waved — bigger/structural items flagged during this audit

| Item | Owner | Note |
|---|---|---|
| Real per-Company scoping for IM and POP (thread an actual `companyId` through routes/domain queries, mirroring GL's own `authorizeTenant`) | IM + POP | The Wave 0 fixes are the correct *tactical* fix given IM's/POP's own company-blind domain models today — this is the larger, multi-day "make IM/POP genuinely Company-scoped" alternative, not required to close the production bug. Only worth picking up if/when IM or POP need real per-Company data isolation for another reason. |
| ~~Whether GL should get its own live peer session~~ | — | **Resolved 2026-09-28** — a GL session is now live and has independently confirmed (not just inherited from POP's read of the code) that GL's own side is clean: every `authorizeTenantFor{Write,Admin,Module,Read}` in `Auth.kt` requires a real `companyId: CompanyId` parameter with no default, and every route site checked (e.g. `RecordInventoryReceiptAndIssueRoutes.kt`) derives it from the actual request body/path, never a hardcoded env var or constant. No `*_COMPANY_ID` env var exists anywhere in GL's source. GL does not have the POP/IM bug pattern. |
| **Decide**: EA's `MeRoutes.kt` silently omits any Company lacking a `CompanyNameRepository` record from an Owner-Admin's `GET /me` response, instead of including it with a placeholder name | EA + user | This is the likely *true* root cause of "Education Runtime" triggering 0.3/0.4 at all - a Company that's real and GL-known but has no EA name record (probably created via a path that bypassed `RegisterCompanyUseCase`, e.g. SchoolAdmissions' auto-provisioning) simply never appears in `companies`, which is what let the `accessLevelAt` bug (0.3/0.4) bite in the first place. Explicitly documented in EA's own code as a *deliberate* prior design choice, not an oversight - so this isn't picked up as a unilateral fix; needs a decision on whether EA should include a placeholder-named entry instead. Separately, whatever code path let Education Runtime skip `RegisterCompanyUseCase` in the first place is its own unresolved data-integrity question (SchoolAdmissions institution linkage is the leading suspect, unconfirmed). |
| SOP self-check (requested 2026-09-28, mirroring the discipline that surfaced IM's/POP's own 0.1R gap): confirmed SOP's `Customer`/`SalesOrder`/`CreditNote`/`ReturnRequest` domain aggregates carry no `companyId`/`tenantId` field at all - `grep` across `src/main/kotlin/.../sop/domain/` returns nothing. Not a new finding or a hidden patch, though - `ea_membership_gateway.kt`'s own KDoc and the 2026-09-23 "Scope WRITE authorization" commit already documented this as SOP's "no fixed, single Company per deployment... none of those domain objects carry a companyId at all today" | SOP | Same underlying shape as IM's/POP's company-blind domain model, but arguably lower-severity here: the 4 write routes that *do* take a per-request `companyId` (record-sale, record-collection, ordinary-sale, issue-credit-note) only forward it to GL for posting - they never use it to scope a read of SOP's own data, so there's no equivalent of POP/IM's "check ANY granted Company" auth patch masking a real isolation gap. Whether SOP's own `SalesOrder`/`Customer`/etc. ever need real per-Company scoping (as opposed to per-Tenant, single-deployment) is the same open question as IM/POP's 0.1R, just not yet urgent enough to have surfaced a bug. |

---

## Change log

- **2026-09-28**: Initial version, distilled from the POP/IM joint audit
  (`docs/Purchase_Inventory_Sales_Cycle_And_Reversals_Scoping.md`). Waves
  0–5 above mirror that audit's §6 task list; the "not yet waved" table adds
  the two structural items flagged in its §7 that don't fit a strict
  dependency wave.
- **2026-09-28 (GL session)**: Added 0.3 (SOP's per-Company auth bug status
  — not yet confirmed, unlike POP/IM) after finding a pushed-but-empty
  `fix/sop-per-company-write-scoping` branch on SOP. Resolved the "GL peer
  session" open question by independently verifying GL's own
  `authorizeTenantFor*` family is not affected by the same bug pattern.
- **2026-09-28 (GL session, later)**: User directly questioned whether the
  0.1/0.2 "check any granted Company" patches are actually right for a
  multi-tenant GLaaS platform — they aren't; both are patches over POP's/
  IM's company-blind domain models, not real per-Company data isolation.
  User decided to hold both patches undeployed and scope the real fix
  first instead. Held 0.1/0.2, added 0.1R (elevated from the "not yet
  waved" table), and handed it to both POP and IM as joint owners per
  direct instruction — each fixes their own service, coordinating on a
  shared shape rather than solving it independently a second time.
- **2026-09-28 (SOP session)**: Resolved 0.3 - `fix/sop-per-company-write-scoping`
  was misread as abandoned; it's actually PR #2, already merged 2026-09-23,
  which is why it shows no unique commits against current master. SOP does
  not have POP/IM's "hardcoded companyId" bug shape at all. While diagnosing
  a live "Couldn't load sales" bug for the "Education Runtime" company
  (reported by the user via screenshot), found and fixed a *different*
  shared bug instead: `CallerMembership.accessLevelAt()` - present
  byte-for-byte identically in GL/SOP/POP/IM - returned `NONE` for an
  Owner-Admin whenever the requested `companyId` was entirely absent from
  EA's `/me` response, instead of applying the intrinsic READ floor
  regardless. Fixed and PR'd in both GL (#53) and SOP (#5) - see the new
  0.4. POP/IM's own Wave 0 fixes already sidestep this variant (they check
  "any Company" rather than one specific `companyId`), so they don't need
  it. Also flagged, not fixed: EA's `MeRoutes.kt` silently drops a Company
  from the Owner-Admin's visible list when it has no `CompanyNameRepository`
  record - the likely true root cause of Education Runtime triggering this
  at all - added to the "not yet waved" table as a decision for EA + the
  user, since it's documented as deliberate prior design, not a bug to
  silently overwrite.
- **2026-09-28 (IM session)**: Confirmed IM has the identical `EntityId`
  plumbing-already-exists shape POP found (§0R.0.1) - `Item`/`Warehouse`
  both have real persisted `entityId` columns and working
  `findAllByEntity()` methods, just never called. Closed out all three
  §0R.0 shared-shape decisions from IM's side. Added IM's own Wave-0R-detail
  task list (§0R.2), scoped to inventory only per the user's explicit
  ownership boundary ("IM must own inventory issues, POP must own Purchase
  and Returns Outwards issues"). Also disclosed an incident: IM's own 0.2
  "check any Company" patch was inadvertently merged to master and
  auto-deployed to production before the hold decision reached this
  session (no gate on master) - reverted immediately, flagged to CM, and
  noted the asymmetry with POP's 0.1 (identical patch shape, left live) as
  an open question rather than resolved unilaterally.
- **2026-09-28 (IM session, later)**: Closed out 0R.2.1. CM confirmed the
  "no real clustering" assumption on both `items` and `warehouses` against
  `im_production` directly. Wrote the backfill migration
  (`IM/src/main/resources/db/migration/V8__backfill_entity_id.sql`),
  verified against a fresh ephemeral Postgres via `integrationTest` before
  committing (migrates cleanly), committed locally (`d0063f3` in IM's own
  repo) - not pushed, handed to CM per the push-only-CM protocol.
- **2026-09-28 (IM session, later still)**: Built out 0R.2.4-0R.2.6 -
  every IM route now lives under `/companies/{companyId}/...`,
  `ImMembershipAuthorizer` takes a real per-request companyId,
  Item/Warehouse routes use `findAllByEntity`, every item/warehouse-id
  route checks ownership (404 on mismatch). Zone/Bin compose via the
  caller's Warehouses; `GET /adjustments/pending` (a gap not previously
  called out - `InventoryAdjustment` has no `entityId` either) filters in
  the application layer. Full suite green (227 tests + integration).
  Pushed to `feature/im-real-per-company-scoping`,
  [PR #7](https://github.com/prodeo-group-dev/fish-inventory-management/pull/7)
  opened - deliberately not merged, since it breaks every existing WEB
  call to IM's old flat paths until 0R.2.2/0R.2.3 land on WEB's side.
- **2026-09-29 (IM session)**: Direct user instruction - checked whether
  SOP has the same per-Company write-action gap POP found in itself
  (0R.1.7). Found three different situations, not one: `record-sale`/
  `record-collection` have no persistence at all (not vulnerable, nothing
  stored to check); `ReturnRequest`/`CreditNote` have no Company concept
  modeled at all (already known, deliberately parked); `Customer` has a
  real, populated `entityId` that nothing checks or filters by anywhere -
  a genuinely new finding, added as 0.5, flagged to SOP directly.
