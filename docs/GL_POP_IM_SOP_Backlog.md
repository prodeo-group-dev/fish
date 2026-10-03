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
tax-jurisdiction rollout, EA/ERP scope, HR, ER/EducationRuntime — see
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
| 0.7 | ~~Build real per-Company scoping for SOP's `Customer`~~, now that 0.6 is resolved | SOP (coordinate shared shape with POP/IM per 0.1R's §0R.0, since this is the same underlying pattern) | 0.6 (resolved) | **All of 0R.3.1-0R.3.6 built and tested** (SOP `df7aba0`+`3cb773f`, WEB `1babe06`), ready for one coordinated merge+deploy, handed to CM. See "Wave 0R detail" below for the full breakdown. |
| 0.8 | ~~**EA response DTO drift crashed every human-authenticated request, platform-wide**~~ - EA added `userId` to `GET /me`'s response 2026-09-28 (`MeRoutes.kt` commit `cf1cef69`, incidental to an unrelated Education Runtime change) and `schoolId` to `CompanySummaryDto` 2026-09-27 - neither field was declared in GL's/POP's/IM's/SOP's own hand-mirrored `EaMyProfileResponseDto`/`EaCompanySummaryDto` copies, and kotlinx.serialization's strict default decoding throws on any undeclared field. Surfaced as a live production 500 on `GET /api/sales` (SOP, caught by WEB ~03:32 2026-09-29), then recurred a second time on `schoolId` specifically (~06:40, also caught by WEB) after the first fix only covered `userId`. | GL + POP + IM + SOP (each patched its own DTO independently, converged on the same fix shape) | none | **All eight gaps (userId × 4 services, schoolId × 4 services) fixed, merged, and confirmed live via CM against the real ECS task-definition image on every service**: GL `sha-d0819bb`→`ac11758` (also re-verified field-for-field, found `schoolId` there too before it could crash), POP `39473ef` (found both fields proactively before either crashed in production), IM `5f223a5` (found both, including flagging the pattern to POP first), SOP `7824bab`+`bc274eb` (found `userId` first via the live crash, `schoolId` second via re-verification, same diligence GL applied). **Platform-wide policy decided and written down** (`CLAUDE.md`, "EA response DTOs: strict decoding, no `ignoreUnknownKeys`", direct instruction: *"This is a Multi-Tenanted Cloud-Native Project. Security is paramount and sacrosanct. There should not be a case where there exists unknown keys being processed."*) - declare every field EA's `/me` actually sends, never loosen the EA-calling client to `ignoreUnknownKeys = true`, even though GL briefly carried that config (2026-09-21) as a resilience trade-off. Explicitly scoped to *this* payload only, not a blanket rule: SOP's own `imHttpClient` (`fetchItemAvailability`'s deliberately partial stock-check DTO) keeps `ignoreUnknownKeys = true` - confirmed correct by direct user decision after CM raised it as a possible inconsistency - since it's a business-data partial read, not an access-control decision. |

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
| 0R.1.6 | ~~`PopMembershipAuthorizer`: take the real per-request companyId, check grants at that specific company (0R.0.3) - replaces the 0.1 "any Company" patch entirely, not layered on top~~ | 0R.1.5, 0R.1.7 | **Done, merged and deployed, 2026-09-30.** Built in direct response to a CRITICAL finding CM caught reviewing this branch against IM's PR #7 before the original coordinated-merge attempt: `PopMembershipAuthorizer` was still checking "granted POP at ANY Company" even after 0R.1.4/0R.1.5/0R.1.7 made routes/data genuinely Company-scoped - a caller with access at Company A could have read/written Company B's real data by changing the URL's `companyId`. Fixed: `resolve()` now checks the Membership's grant at the real per-request companyId specifically. **Coordinated three-way cutover, fast-tracked during a SEV-1 cross-tenant data-exposure investigation**: [POP PR #10](https://github.com/prodeo-group-dev/fish-purchase-order-processing/pull/10) (`cf39c34`) + a same-day follow-up fixing a stale integration test CM caught in CI (`7aad5cd`), [WEB PR #12](https://github.com/prodeo-group-dev/fish-gl-web/pull/12) (`b862dc3`), [IM PR #7](https://github.com/prodeo-group-dev/fish-inventory-management/pull/7) (`038e53b`) - all merged and deployed together (POP: task-def `:21`, image `sha-7aad5cd`, confirmed live and stable by CM). 220 tests green on POP's side. **All of Wave 0R.1 (0R.1.1-0R.1.7) is now live in production.** **Correction, same day**: POP's own live pre-cutover code (the 0.1 "any Company" patch plus genuinely unscoped Supplier/PO reads) was flagged as a *possible* root cause of the SEV-1 and used partly to justify fast-tracking this cutover ahead of SOP's own equivalent work - CM later confirmed it was **not** the actual mechanism. The real cause: a genuine, legitimate ACCOUNTANT/WRITE staff Membership (Charles Soyinka, confirmed real by the user - "he is supposed to be a staff on my tenancy") surfaced during an attempt to also start a separate Tenant, compounded by a client-side stale-session gap on WEB's sign-up form (fixed via a "Continue as X?" gate), not a backend data-scoping leak. Wave 0R's fix here was still a real, independently-confirmed vulnerability worth shipping regardless - it just wasn't *this* incident's cause. Recorded here so the record doesn't overstate the connection. |

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

~~Nothing here touches GL or POP~~ - **this line was wrong, confirmed live-broken, 2026-10-01.** It's true that the service-account calls POP/SOP make into IM permanently bypass the EA-membership *check* (`VerifiedIdentity.isServiceAccount`'s own KDoc) - but PR #7 also moved the URL *shape* every route lives at, which is a separate axis from the auth bypass and genuinely does affect module-to-module crossings: every route, including `/items/{id}/receive`/`/items/{id}/issue`, got nested under `/companies/{companyId}` with no un-scoped fallback. POP's and SOP's own `KtorImGateway`s still pointed at the old flat paths, so every real goods-receipt/goods-issue call into IM 404'd from the moment `038e53b` deployed until both were fixed (`companyId` sourced from each call site's own real Company value - `purchaseOrder.entityId` on POP's side, `request.companyId`/`request.entityId` on SOP's four call sites - not a cosmetic URL patch). Both sides added regression tests asserting the actual request URL, the gap plain response-parsing tests couldn't have caught. **This incident was handled entirely through peer `SendMessage` traffic with nothing written here until now** - a real coordination-discipline miss, caught by a direct instruction to go back and fix it, not something any session caught proactively. See the change log for the full timeline and whoever-owns-what breakdown.

---

## Wave 0R detail — SOP's own task breakdown for real per-Company `Customer` scoping

**Priority, 2026-09-30** (relayed via GL, direct user instruction): item 0.7, following the same §0R.0 shared-shape decisions POP/IM already closed (`EntityId` = `CompanyId`, path-based `/companies/{companyId}/...`, no "any Company" patch to unwind here since SOP never had that bug shape). Scope is much smaller than POP's (~25 routes) or IM's (~15) - only the 3 `Customer` routes need this; `SalesOrder`/`ReturnRequest`/`CreditNote` already take `companyId` as a request-body field where they need it (0.3/0.4's resolution) and aren't touched here.

**One genuinely harder problem than POP/IM had, found while scoping** - checked `V2__sales_orders.sql` directly: `sales_orders` only persists the same garbage `entity_id` column `Customer` has, never a real `company_id`. Unlike POP/IM (single Company per deployment, so "backfill every row to the one real Company id" was trivially safe and CM confirmed it empirically), SOP's own write routes (`OrdinarySaleRoutes.kt`) already accept a real per-request `companyId` today - meaning if this Tenant has ever recorded sales against more than one real Company, there is no reliable way to reconstruct which Company an existing `Customer` row actually belongs to from SOP's own data alone. Backfilling blindly to "one" Company id could silently misattribute a real customer. Needs an empirical check before 0R.3.1 can proceed safely - see that task.

| # | Task | Depends on | Notes |
|---|---|---|---|
| 0R.3.1 | ~~Backfill migration: set every existing `customers` row's `entity_id` to the real Company id~~ | §0R.0.1 decided, **and the multi-Company question above resolved first** | **Resolved, built and tested.** Femi confirmed directly, 2026-09-30: "I will tell you when we have actual live data being uploaded. Right now we are still in development" - the original risk (misattributing a real customer's Company) doesn't exist with no live data yet, so the read-only check is no longer needed as a precondition. Migration written: [SOP commit 3cb773f](https://github.com/prodeo-group-dev/fish-sales-order-processing) on `feature/wave-0r3-customer-company-scoping` (`V6__backfill_entity_id.sql`), same real Company id POP's/IM's own backfills used. Flyway runs it before `main()` opens the HTTP port, so it lands atomically in the same deploy as 0R.3.2-0R.3.6 - no separate manual step. |
| 0R.3.2 | ~~WEB: stop calling `generateEntityId()` in `sopCustomers.ts`; send the real `companyId`... on `POST /customers` instead~~ | §0R.0.1 decided | **Merged and deployed.** [WEB commit 0e4f9f4](https://github.com/prodeo-group-dev/fish-gl-web) (PR #16), live in production - verified directly by WEB session 2026-10-01 (production `index.html` bundle hash changed, matches this deploy, post-dates the brief ~12h outage this caused while WEB's own CI/CD was being stood up - see Wave 1's new WEB CI/CD item). |
| 0R.3.3 | ~~WEB: rewrite `sopCustomers.ts`'s 3 functions... to the `/companies/{companyId}/...` path shape~~ | §0R.0.2 decided | **Merged and deployed**, same commit as 0R.3.2 - caught a 4th call site (`SopSalesTab.tsx`) missed on the first pass by `npm run build` failing with a real arity error, not assumed clean. `npx tsc --noEmit` and `npm run build` both clean. |
| 0R.3.4 | ~~`CustomerRepository`: add per-Company filtering, matching POP's own signature~~ | 0R.3.1 (real data to filter), §0R.0.1 | **Built and tested.** Changed `findAll()` to `findAll(companyId: EntityId)` directly (matching POP's own shipped `SupplierRepository.findAll(companyId)` signature exactly, not a parallel `findAllByEntity` method as first planned - POP's real precedent is cleaner). `findById` confirmed to have no other callers needing a company-check. |
| 0R.3.5 | ~~Routes: restructure the 3 `Customer` routes under `/companies/{companyId}/customers...`~~ | 0R.3.3, 0R.3.4 | **Merged and deployed**, [SOP commit 479eba6](https://github.com/prodeo-group-dev/fish-sales-order-processing) (PR #9). Also fixed the original 0.5/0.6 bug directly: `ListCustomersWithBalancesUseCase` already took `companyId` as a parameter but never actually used it to scope the Customer list, only the GL balance lookup. 272 tests green. **All of Wave 0R.3 (0R.3.1-0R.3.6) is now live** - SOP's deploy briefly broke WEB in production (~12h, no backward-compat fallback on the route rename) since WEB had no CI/CD to redeploy automatically; CM built WEB a real Jenkinsfile mid-incident and deployed WEB's matching cutover (0e4f9f4) through it, confirmed live 2026-10-01T01:04Z. |
| 0R.3.6 | ~~Add `authorizeSopForReadAt(companyId: String)` to `Auth.kt`~~ | none, can be written any time | **Built**, same commit as 0R.3.5 - mirrors `authorizeSopForWriteAt` exactly. |

No authorizer "flip last" step is needed the way POP's 0R.1.6/IM's 0R.2.6 needed one - `SopMembershipAuthorizer`'s underlying `accessLevelAt(companyId)`/`grantedModulesAt(companyId)` already take a real per-request `companyId` (fixed in 0.3/0.4's `accessLevelAt` intrinsic-floor work); there's no "any Company" patch here to replace, only new call sites (0R.3.6) to add and wire in (0R.3.5).

Nothing here touches GL, POP, or IM - `Customer` is purely SOP's own aggregate, and the GL-crossing sale-recording routes (`OrdinarySaleRoutes.kt`, already correctly per-Company via 0.3/0.4) are unaffected.

---

## Wave 1 — small follow-ups from Wave 0 (style/consistency, not correctness)

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 1.1 | ~~Converge POP's inline `.any {}` auth check and IM's named `CallerMembership.hasModuleGrantedAnywhere()` helper on one shape~~ | GL/POP/IM/SOP (joint decision) | 0.1, 0.2 shipped | **Resolved as a byproduct, 2026-10-01 (POP session, checked directly against both services' current code, not assumed from this doc's own prose).** Both `.any {}` shapes this item was about no longer exist - POP's 0R.1.6 and IM's 0R.2.6 each independently replaced their own tactical "any Company" check with a real per-request-companyId check, landing on the *identical* shape (`accessLevelAt(companyId).atLeast(min) && module in grantedModulesAt(companyId)`, confirmed byte-for-byte equivalent in `POP/.../Auth.kt` and `IM/.../Auth.kt`) - not because anyone worked this item, but because both services independently converged on the same precedent (GL's own `authorizeTenant`) while building their real fixes. Nothing left to hoist/share - no further action needed. |

No longer applicable - both services' fixes converged independently.

---

## Wave 2 — IM's receipt-side generalization

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 2.1 | ~~Generalize `IM/RecordGoodsReceiptUseCase`: make `contraAccountId` caller-overridable (default to AP control account for existing PO-receipt callers, mirroring `RecordGoodsIssueUseCase`'s 2026-09-03 precedent exactly) and make the PO-specific `purchaseOrderReference` field generic (or add a parallel non-PO field)~~ | IM | none (can start any time) | **Done, 2026-10-01 (commit `31f3a3a`, local, handed to CM).** `Request.apControlAccountId` renamed to `contraAccountId`, now caller-overridable via an optional request-body field on `/items/{id}/receive` (route defaults to the GL posting context's AP control account when omitted, matching every existing caller's behaviour exactly). `purchaseOrderReference` kept as-is, documented as a generic reference string rather than renamed - no schema/wire-contract change, mirrors the identical already-shipped precedent on `GoodsIssueConfirmation.salesOrderReference` (POP's Returns Outwards already reuses that field the same way). Two new end-to-end tests cover both the override and default paths. 229 unit tests + integration tests pass. SOP's Wave 3.1 is unblocked - pinging them directly. |

No GL change needed — `RecordInventoryReceiptUseCase` on GL's side is
already fully generic (confirmed by reading it directly). This is entirely
IM's own application-layer file.

---

## Wave 3 — Returns Inwards inventory-value posting

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 3.1 | ~~Add the SOP→IM crossing for Returns Inwards: a new `ImGateway.recordGoodsReceipt`-equivalent call from SOP, mirroring the existing `ImGateway.recordGoodsIssue` call SOP already has elsewhere, invoked after `InspectReturnedGoodsUseCase` determines a `Resaleable` disposition~~ | SOP (calling IM's new interface from 2.1) | 2.1 | **Done, merged and deployed, 2026-10-01** - [SOP commit 23e08aa](https://github.com/prodeo-group-dev/fish-sales-order-processing). Credits inventory back in (Dr Inventory / Cr Sales Returns) for every Resaleable disposition on inspection. Found and closed a real unscoped gap while building: neither `ReturnRequestLine` nor the originating `SalesOrderLine` carried an IM Item id or cost field - added `ReturnRequestLine.itemId` (optional) and `ReturnLineDisposition.costReceived` (optional Money, required only for Resaleable, validated in the value object's own init), plus a cross-check in `ReturnRequest.inspect()`. `V8__return_item_id_and_cost_received.sql`, both columns nullable. Domain transition first, IM call(s) second, persist only on success - known limitation: no compensating transaction if a later line's IM call fails after an earlier one succeeded (same shape IM's own multi-step flows already accept). Reviewed and pushed by CM, deploy in progress at time of writing - not yet confirmed live. This closes the one real accounting-correctness gap left in the reversal flows. |

This closes the one real accounting-correctness gap in the reversal flows:
today a Resaleable Returns-Inwards credit note posts the AR side
(`RecordSalesReturnUseCase`) but not the inventory-value side
(`Dr Inventory / Cr Sales Returns`).

---

## Wave 4 — Returns Inwards disposition decisions + build

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 4.1 | ~~**Decide**: Scrap disposition posting — reuse `InventoryAdjustment`'s existing `DAMAGE` reason (no new IM mechanism), or does it need its own write-off path traceable back to the originating `ReturnRequest`?~~ | IM + SOP (joint decision) | none — can be decided in parallel with Wave 2/3 | **Decided, 2026-10-01 (direct user decision): reuse `DAMAGE`.** Matches IM's own recommendation - no new write-off mechanism, ReturnRequest-traceability gap stays parked unless SOP's reporting genuinely needs the hard link later. |
| 4.2 | ~~**Decide**: Repairable disposition — does "quarantine" need a real IM location-state concept (possibly reusing the existing `LocationState`/bins mechanism as-is), or is this genuinely unbuilt inventory-state modeling?~~ | IM | none | **Decided, 2026-10-01 (IM).** No new location-state concept needed - `LocationState` (`IN_TRANSIT`/`ON_HAND`) is scoped specifically to `InTransitShipment`'s own lifecycle, confirmed by reading it directly, and doesn't fit "repairable, not yet saleable" at all. The existing Bin/Warehouse/Zone hierarchy plus the already-built `TransferStockUseCase` already model this: a company defines its own "Repair"/"Quarantine" Bin, and moving stock there is an ordinary transfer, no new mechanism. **Flagged implication for 4.4, not yet confirmed with SOP**: since a Repairable item isn't written off (still an asset, still has value), its GL posting may be the *same* crossing as Resaleable (Dr Inventory / Cr Sales Returns, via 3.1/2.1) - "quarantine" would be a purely operational concern (don't let it get picked for a new sale), not a different accounting treatment. If right, 4.4 may need no separate IM work beyond 3.1/2.1, just an operational transfer-to-repair-bin step. |
| 4.3 | ~~Build the Scrap disposition posting~~ | IM/SOP | 4.1 decided; 3.1 has now shipped, so Resaleable is the proven pattern | **Built and tested, 2026-10-01 (SOP session)** - [SOP commit 47938f2](https://github.com/prodeo-group-dev/fish-sales-order-processing) on `fix/im-gateway-company-scoped-paths` (stacked on the companyId-fix commit `8b1226b` the same branch already carries - Wave 4.3's `ImGateway` calls need that fix to even reach IM), 297 tests green, handed to CM. `requiresApproval = true` (direct user decision, via `AskUserQuestion`) - the Store Manager gate is a separate inventory/financial control from the Sales-Manager-approval + Warehouse-inspection a return already went through, not a redundant check of the same thing. Creating the adjustment does **not** post to GL immediately - only IM's own Store-Manager-triggered `ApproveInventoryAdjustmentUseCase` does that, using `Item`'s own computed cost rather than this call's `estimatedValue` estimate. Renamed `ReturnLineDisposition.costReceived` -> `estimatedValue` (now serves both Resaleable-credit and Scrap-write-off meanings) - safe, neither field was wired to WEB yet. **Also closed a real gap this surfaced**: `ReturnRequest.inspect()`'s itemId cross-check only covered Resaleable - generalized to Scrap too, since it also needs one to reach IM; would otherwise have been a live NPE the first time a Scrap line had no `itemId`, same shape as the companyId incident below, caught before shipping this time. |
| 4.4 | ~~Build the Repairable disposition posting~~ | IM/SOP | 4.2 decided; ideally after 3.1 ships | **Built and tested, 2026-10-01 (SOP session)** - [SOP commit c6e3e64](https://github.com/prodeo-group-dev/fish-sales-order-processing) on `fix/im-gateway-company-scoped-paths` (same branch as the companyId fix/Wave 4.3), 302 tests green, handed to CM. Confirmed via `AskUserQuestion`: IM's own flagged implication was right - "quarantine" is a pure operational bin transfer, not a different accounting treatment, so Repairable posts through the exact same crossing Resaleable already uses (`recordGoodsReceipt`), immediately, at whatever caller-supplied `estimatedValue` reflects the item's reduced (needs-repair) condition - no new IM mechanism, no deferred-until-repair workflow. Generalized `ReturnLineDisposition`'s validation and `ReturnRequest.inspect()`'s itemId cross-check to cover all three IM-crossing dispositions (Resaleable/Repairable/Scrap); `InspectReturnedGoodsUseCase` now sends the real disposition name as IM's `condition` field instead of a hardcoded `"RESALEABLE"`. **All of Wave 4 is now closed on SOP's side** - 4.1 (decided)/4.2 (decided, IM)/4.3 (built)/4.4 (built). |

---

## Wave 5 — lower priority, no dependency relationship to the above

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| 5.1 | RMA document generation (FR-RA2, Returns Inwards spec) | SOP | none | **Built and tested, 2026-10-01 (SOP session)**, [SOP commit 340f42e](https://github.com/prodeo-group-dev/fish-sales-order-processing) on `feature/wave-5.1-rma-document-generation`, 276 tests green - handed to CM. Picked up per the "check your dependency-ordered backlog and start" instruction while Wave 3.1 sits blocked on IM's Wave 2.1 (see Coordination log). Mirrors POP's `EOrder`/`OrderNotificationGateway`/`SesOrderNotificationGateway` pattern exactly: `Customer.contactEmail` (new, optional field, `V7__customer_contact_email.sql`), `RmaNotice.render()` (pure rendering, email-only - no portal/SMS, since FR-RA2 only names email/portal and `Customer` has no `contactPhone`), `CustomerNotificationGateway`/`SesCustomerNotificationGateway`/`UnconfiguredCustomerNotificationGateway`, wired into `ApproveReturnRequestUseCase` the same best-effort way POP's `ResolveReturnOutwardsUseCase.approve()` notifies its Supplier - never blocks the approval outcome. RMA number is derived from `ReturnRequest.id` (`RMA-<8 hex chars>`), not a new persisted sequence. **Needs one small follow-up from CM once merged/deployed**: `Infrastructure/sop.tf` has no `ses:SendEmail` IAM policy or `SOP_NOTIFICATION_FROM_EMAIL` env var yet (same shape as `pop.tf`'s) - ships safely without it (falls back to `UnconfiguredCustomerNotificationGateway`, same as POP did pre-SES-wiring). "Or portal" is deliberately not built - no Customer-facing access token concept exists in SOP (unlike POP's Supplier-facing `OrderAccessToken`); email alone satisfies FR-RA2's "email/portal" either/or. |
| 5.2 | Returns reporting/analytics (FR-RE1/FR-RE2) | SOP | none | **Built and tested, 2026-10-01 (SOP session)**, [SOP commit 15fcf8c](https://github.com/prodeo-group-dev/fish-sales-order-processing) on `feature/wave-5.2-returns-analytics`, 283 tests green - handed to CM. Picked up while Wave 3.1 still sat blocked on IM's Wave 2.1 (now unblocked - IM's own Wave 2.1 is done, see below). New `GenerateReturnsAnalyticsReportUseCase` (pure cross-aggregate read, no new persisted aggregate) + `GET /companies/{companyId}/returns-analytics`. **Deliberately narrower than FR-RE1/FR-RE2's full text, checked against the real domain model before building rather than guessed**: by-Customer and by-`ReasonCode` breakdowns (count/quantity/credited value, grouped by currency) and two exception buckets (received-not-inspected, inspected-not-credited) are built; "by product" (no SKU identity on `ReturnRequestLine`, only free-text `description`), "by region" (no region field anywhere), "value/volume over time" (no audit-timestamp field on `ReturnRequest`/`CreditNote`, only a caller-supplied `requestedAt` per line), "high return rate" (no sales-volume denominator available), and "delayed credit issuance" (same missing-timestamp gap) are all explicitly parked, not faked - see the use case's own KDoc for the full reasoning per dimension. Added `CreditNoteRepository.findAll()` (mirrors `ReturnRequestRepository.findAll()`'s own precedent) to support the credited-value aggregation. |

Can run in parallel with any other wave, or whenever prioritized — genuinely
separable from the accounting-correctness work above.

---

## Backlog, not yet waved — bigger/structural items flagged during this audit

| Item | Owner | Note |
|---|---|---|
| Real per-Company scoping for IM and POP (thread an actual `companyId` through routes/domain queries, mirroring GL's own `authorizeTenant`) | IM + POP | The Wave 0 fixes are the correct *tactical* fix given IM's/POP's own company-blind domain models today — this is the larger, multi-day "make IM/POP genuinely Company-scoped" alternative, not required to close the production bug. Only worth picking up if/when IM or POP need real per-Company data isolation for another reason. |
| ~~Whether GL should get its own live peer session~~ | — | **Resolved 2026-09-28** — a GL session is now live and has independently confirmed (not just inherited from POP's read of the code) that GL's own side is clean: every `authorizeTenantFor{Write,Admin,Module,Read}` in `Auth.kt` requires a real `companyId: CompanyId` parameter with no default, and every route site checked (e.g. `RecordInventoryReceiptAndIssueRoutes.kt`) derives it from the actual request body/path, never a hardcoded env var or constant. No `*_COMPANY_ID` env var exists anywhere in GL's source. GL does not have the POP/IM bug pattern. |
| **Decide**: EA's `MeRoutes.kt` silently omits any Company lacking a `CompanyNameRepository` record from an Owner-Admin's `GET /me` response, instead of including it with a placeholder name | EA + user | This is the likely *true* root cause of "Education Runtime" triggering 0.3/0.4 at all - a Company that's real and GL-known but has no EA name record (probably created via a path that bypassed `RegisterCompanyUseCase`, e.g. Education Runtime's auto-provisioning) simply never appears in `companies`, which is what let the `accessLevelAt` bug (0.3/0.4) bite in the first place. Explicitly documented in EA's own code as a *deliberate* prior design choice, not an oversight - so this isn't picked up as a unilateral fix; needs a decision on whether EA should include a placeholder-named entry instead. Separately, whatever code path let Education Runtime skip `RegisterCompanyUseCase` in the first place is its own unresolved data-integrity question (Education Runtime institution linkage is the leading suspect, unconfirmed). |
| SOP self-check (requested 2026-09-28, mirroring the discipline that surfaced IM's/POP's own 0.1R gap): confirmed SOP's `Customer`/`SalesOrder`/`CreditNote`/`ReturnRequest` domain aggregates carry no `companyId`/`tenantId` field at all - `grep` across `src/main/kotlin/.../sop/domain/` returns nothing. Not a new finding or a hidden patch, though - `ea_membership_gateway.kt`'s own KDoc and the 2026-09-23 "Scope WRITE authorization" commit already documented this as SOP's "no fixed, single Company per deployment... none of those domain objects carry a companyId at all today" | SOP | Same underlying shape as IM's/POP's company-blind domain model, but arguably lower-severity here: the 4 write routes that *do* take a per-request `companyId` (record-sale, record-collection, ordinary-sale, issue-credit-note) only forward it to GL for posting - they never use it to scope a read of SOP's own data, so there's no equivalent of POP/IM's "check ANY granted Company" auth patch masking a real isolation gap. Whether SOP's own `SalesOrder`/`Customer`/etc. ever need real per-Company scoping (as opposed to per-Tenant, single-deployment) is the same open question as IM/POP's 0.1R, just not yet urgent enough to have surfaced a bug. |
| WEB: no CI/CD pipeline existed at all until 2026-10-01 - every deploy was a fully manual `./deploy.sh` run, no `Jenkinsfile`, no GitHub webhooks configured. Surfaced as a real incident: SOP's Wave 0R.3 route rename (above) broke WEB's Sales tab in production for ~12h because nobody ran the manual script after the merge. | WEB + CM | **Resolved 2026-10-01** - CM built WEB a real Jenkinsfile (install/lint/build/deploy against `prodeo_web`, S3+CloudFront) mid-incident, through 3 real build failures (no Node on the bare host, a duplicate `environment{}` block, npm's `HOME` resolution breaking under a non-passwd container user) before going green. Future WEB changes deploy automatically on merge to master now, same as every sibling service. |
| WEB: a Membership holder on one Tenant has no UI path to also start their own separate new Tenant, while keeping the existing Membership | WEB + EA | Surfaced 2026-09-29 via a false-alarm cross-tenant "breach" report that turned out to be intended behavior (a User can hold concurrent Memberships across Tenants) colliding with a missing feature. `GET /me`'s `tenants` array and `CompanyPickerScreen` already support this structurally; the only gap is the "+ start your own Tenant" entry point. Needs EA to confirm `OnboardTenantUseCase`/`RegisterCompanyUseCase` don't assume a brand-new User with zero existing Memberships before WEB builds the entry point. Not started - claimed in Coordination log, confirming with EA first. |
| WEB: no self-service way to provision/link a School (SchoolAdmissions) for a Company that predates EA's registration-time auto-provisioning flow | WEB + EA | Surfaced 2026-09-30 - "Prodeo Capital" had no linked `schoolId`, and the only known fix is manually re-calling `POST /tenants/{tenantId}/company-registration` with `industryType: SCHOOL` (confirmed safe/idempotent by EA), which nothing in the UI surfaces or explains. Not started. |
| IM has no reservation/commitment concept at all - `quantityOnHand` exists, but nothing tracks "committed against an open Sales Order," so EA's UC-BO07 "Monitor Inventory Levels" can't report allocated-vs-available stock | IM + SOP | Flagged by EA 2026-10-01 while reassessing its own backlog (`EA_Development_Backlog.md` item 05's UC-BO table) - genuinely IM/SOP's to prioritize, not EA's to build. **Confirmed independently from SOP's own side too**: `CreateSalesOrderUseCase`/`CheckInventoryAvailabilityUseCase` both explicitly document `allocatedQuantity` as always zero, same root gap. Not scoped or decided here; a real design question (what triggers a reservation - SalesOrder creation, aval confirmation, fulfilment? does it live on `Item` or a new aggregate?) worth its own discussion before picking anything. |
| IM has no bulk "items currently low on stock" route - only `GET /items/{id}/inventory-levels` (per-item) | IM | Direct user instruction, relayed via EA, 2026-10-01: this capability belongs inside IM, not composed at EA's layer via N+1 (same shape as the Approvals Queue N+1 gaps already flagged elsewhere). Verified directly - no bulk route exists. Suggested shape (EA's, not decided): `GET /companies/{companyId}/items/low-stock`, same per-Company pattern `adjustments/pending` already uses, returning items where `ReplenishmentPolicy.evaluate()` flags `lowStock = true`, skipping items with no policy configured (same unconfigured-vs-not-low distinction `inventory-levels` already makes). Not built yet. |
| No event bus exists anywhere on the platform - every GL-crossing call today (SOP↔GL, POP/SOP↔IM, SchoolAdmissions↔SOP) is synchronous HTTP. A new local spec (`FiSH-ER-Education-Runtime-Technical-Req-Spec-and-Use-Cases-v0.1.md`, gleaned 2026-10-01, not yet in this repo) formally specifies FIN-INT as an event-driven contract instead (outbox pattern, at-least-once delivery, idempotency keys, per-account ordering, dead-letter queue + replay, 6-month deprecation notice on schema changes) | GL + SOP | Not a correction to anything already built - a genuine architectural question for whoever next extends GL/SOP's integration surface (The Principal/SchoolAdmissions' own fee-billing work is the most likely next caller). Build toward the event-driven contract, or keep today's synchronous pattern and treat this spec's FIN-INT section as aspirational - undecided, not started. |
| Currency conflict, flagged 2026-10-01, scoped 2026-10-02 - see "Multi-currency conflict detail" section below | GL + WEB + user (decision) | Scoped, not resolved - the real blocking item turned out to be `Jurisdiction`'s closed enum (no `GH`/`GM`), not `Money`/`Company`, which already accept any currency today. |
| Pass-through liability posting pattern for third-party fee collections (exam registration fees, PTA collections) - the same spec's CoA mapping (§2.7) routes these to a liability account, never revenue, a posting shape distinct from every fee-item mapping GL's CoA-mapping mechanism currently handles | GL | Not yet checked against GL's actual code whether the existing CoA-mapping mechanism (built for VAT/tax lines) can already express "post this item to a configured liability account instead of revenue," or whether that's a real gap. Relevant once The Principal/SchoolAdmissions' own Fee Desk work reaches exam-fee/PTA-collection billing (`BK-FEE-6`/Epic 6 in `ER/Principal/docs/The_Principal_Backlog.md`). |
| Offline cash receipt-number-range allocation - no mechanism exists for FiSH to allocate a block of receipt numbers to an unregistered/offline device so it can issue provisional receipts without connectivity, confirmed on sync | GL + SOP | FIN-INT-013 in the same spec. A concrete, net-new capability gap in `Receipt`/`Payment` - relevant to The Principal/SchoolAdmissions' own offline-first requirement (`BK-PLT-6`) once on-device fee receipting is built there. Not scoped. |
| FIN-INT-017 role mapping (ER Bursar ↔ FiSH AR clerk, and other school-specific roles like Registrar/CPFP/Form Master) - EA's Role/Membership model has no school-specific role vocabulary today | EA | Same spec, §3.2/§4.16. The Principal's own `StaffAssignment` store already has its own parallel role set (`TEACHER`/`REGISTRAR`/`SCHOOL_ADMIN`/etc., per `The_Principal_Backlog.md`'s 2026-09-20 change-log entry noting "EA's own `Role` enum has nothing matching these") - whether that stays a separate ER-owned vocabulary EA never needs to know about, or needs an explicit mapping onto EA's own Role/Membership model for billing-role purposes, is undecided. |
| ~~GL's `AccountsReceivableAging` (domain/sales/accounts_receivable_aging.kt) has no HTTP route exposing it at all~~ | GL | **Resolved 2026-10-02** - new `ComputeAccountsReceivableAgingUseCase` + `POST /companies/{companyId}/accounts-receivable-aging` (GL `d29ce6d`, live in production, Jenkins build #56), mirroring `ComputeCustomerBalancesUseCase`/`CustomerBalancesRoutes`'s exact shape and returning the full `AgingBucketAmount` breakdown instead of just the scalar total. Additive only - the existing `customer-balances` endpoint is unchanged. 9 new tests (5 use-case, 4 route), full suite green (817/817, verified by CM with `--rerun`). **AP's identical gap resolved the same day too** - see the row below. |
| ~~GL's `AccountsPayableAging` (domain/purchasing/accounts_payable_aging.kt) has the same scalar-only gap~~ | GL | **Resolved 2026-10-02**, per direct user instruction - new `ComputeAccountsPayableAgingUseCase` + `POST /companies/{companyId}/accounts-payable-aging` (GL `5c5c8cb`, local, handed to CM), mirroring the AR route above exactly (and `ComputeVendorBalancesUseCase`/`VendorBalancesRoutes`'s existing shape). Additive only - the existing `vendor-balances` endpoint is unchanged. 9 new tests (5 use-case, 4 route), full suite green. |
| GL's `purchase-posting-context` endpoint has no `suspenseAccountId` field, unlike `inventory-posting-context` (GL `8a04ee6`) | GL | Found 2026-10-02 while building POP's `ImportOpeningApLineUseCase` (Opening Figures CSV Upload step 4, AP half). Doesn't block that use case - `Request.suspenseAccountId` is caller-supplied, the same precedent IM's own still-unbuilt route layer already set. Will block the shared CSV/route layer once that's built, since the importer will need to resolve the Suspense account itself rather than require the caller to already know it. Not scoped or started. |

---

## Multi-currency conflict detail — Scope, decisions needed, and dependency-ordered tasks

**Trigger:** direct instruction, 2026-10-02 - "Scope, Plan, Task and Order the Tasks according to dependencies" for the currency conflict flagged in the table above. Everything below is grounded in reading the actual code first, not assumed from the doc's own prior one-line framing.

### Scope

**The conflict as first flagged** (2026-10-01): a new local spec (`FiSH-ER-Education-Runtime-Technical-Req-Spec-and-Use-Cases-v0.1.md`, ER-FEE-007) wants per-school billing in NGN/GHS/SLE/LRD/USD/GMD/GNF/XOF, apparently colliding with the documented Mano River decision (`docs/SL/SL_Tax_And_Currency_Settings.md`, 2026-08-22) that FiSH "only recognises `SLE`," with LRD/GNF/XOF explicitly `onboarded: false`.

**Reading the actual code narrows this a lot.** Checked directly, not assumed:
- `common/Money.kt` takes any `java.util.Currency` - no allow-list anywhere. The amount is normalized to `currency.defaultFractionDigits` generically, so a 0-decimal currency (GNF) is already handled by construction, not a special case.
- `Company.baseCurrency: Currency` (`GL/domain/tenancy/company.kt`) has no jurisdiction-currency cross-validation in `Company.create()` - nothing stops a Company being created with any ISO code today.
- `TenantRoutes.kt` does `Currency.getInstance(request.companyBaseCurrency)` - accepts any valid ISO 4217 code the JVM recognizes, rejecting only genuinely invalid codes, not a closed list.
- `Currency.getInstance("SLE")` is already live-tested (`CompanyTest.kt`, `MoneyTest.kt`, `AddCompanyToTenantUseCaseIntegrationTest.kt`) - SLE works fine on this JDK, and by the same mechanism NGN/GHS/GMD/LRD/GNF/XOF (all long-standing ISO 4217 codes) would too.
- **The one real, concrete code-level gate is in WEB**, not GL: `AddCompanyForm.tsx`/`OnboardingWizard.tsx` each hardcode an identical `CURRENCIES = ['GBP', 'EUR', 'USD', 'NGN', 'SLE']` array (duplicated verbatim in both files - a separate, lower-priority cleanup item, not fixed here). GHS/GMD/LRD/GNF/XOF are missing from it; NGN and USD are already there despite neither being named "onboarded" in the SL doc's own decision.
- **The bigger, previously-unflagged blocker**: `Jurisdiction` (`GL/domain/common/jurisdiction.kt`) is a closed 7-value enum - `UK, IE, NG, SL, LR, GN, CI` - with no `GH` (Ghana) or `GM` (The Gambia). A Company can't be created for either country's jurisdiction *at all* today, independent of currency - this is the real precondition the currency question sits behind for those two markets specifically, not something the original flagging caught.
- No FX/exchange-rate mechanism exists anywhere on the platform (confirmed in this file's own project history - IAS 21 FX is a named-but-unbuilt future GL item). This only matters for a Tenant/group whose Companies span more than one currency and need consolidated reporting - a pre-existing, separately-tracked gap (`project_gl_engine_reporting_scope.md`'s "Group reporting = unbuilt"), not something this conflict newly creates. A single school Company operating in one new currency, with no cross-currency reporting promised, needs no FX work at all.

So the real shape of this problem is: **a policy decision (which currencies, when) blocking two cheap, independent, low-risk code changes** (a WEB dropdown edit; a `Jurisdiction` enum addition) - not a deep platform rebuild.

### Decisions needed (blocking - reconcile before any task below starts)

| # | Decision | Recommendation | Status |
|---|---|---|---|
| CUR.0.1 | Does FiSH onboard currencies beyond the current `GBP/EUR/USD/NGN/SLE` set, and if so which of GHS/GMD/LRD/GNF/XOF, and on what timeline? | Per-market as each market actually gets a paying tenant (the same "Ireland first, not simultaneous" sequencing precedent this project already uses elsewhere), not all five at once speculatively. | **Decided, 2026-10-02 (direct user decision): hold all five.** None of GHS/GMD/LRD/GNF/XOF onboard now - revisit per-market only once a real paying tenant actually needs one. **Modeling note, 2026-10-03 (direct user observation)**: currency and jurisdiction are a genuine one-to-many relationship, not one-to-one - `docs/LR/LR_Tax_And_Currency_Settings.md` already documents Liberia's own dual LRD/USD circulation as a real, current fact, not a hypothetical. If a future task ever wants to validate "is this currency actually valid for this jurisdiction" (rather than leaving it fully open, as today), that check must be modeled as `jurisdiction -> set of currencies`, not `jurisdiction -> one currency` - flagged explicitly so the next person to pick this up doesn't assume a 1:1 lookup and build the narrower shape by mistake. |
| CUR.0.2 | Does onboarding a new base currency require FX/consolidation support to exist first? | No - a single-currency Company carries zero cross-currency risk on its own; FX is only a prerequisite for a *group* spanning currencies, which is the pre-existing, separately-tracked "Group reporting = unbuilt" item, not a new dependency this conflict creates. | **Recommended, not confirmed** |
| CUR.0.3 | Does a Ghana/Gambia school Company need `Jurisdiction.GH`/`GM` added before anything else here is useful? | Yes - without it, no Company can be created for either country regardless of what currency it would use. This is the actual first task, not the currency dropdown. | **Confirmed by reading the code.** See CUR.0.1's 2026-10-03 modeling note - the same one-to-many point applies here too: a future `Jurisdiction.GH`/`GM` addition should not assume either maps to exactly one currency. |
| CUR.0.4 | Who owns this work - GL (the platform's own onboarding surface) or whoever next picks up The Principal/Education Runtime's Fee Desk work (the actual source of the pressure)? | GL for CUR.1.1-CUR.1.3 below (platform-level, same owner as the existing `Jurisdiction`/currency code); Education Runtime's own thread for anything specific to school billing itself (none identified yet). | **Decided** - no business-judgment call here, a clean engineering-ownership split following the project's existing division of labor. |

### Task list, dependency ordered

| # | Task | Depends on | Notes |
|---|---|---|---|
| CUR.1.2 | ~~Write a real passing test proving `Money`/`Company.create()` already accept GHS/GMD/LRD/GNF/XOF today~~ | none - pure verification, safe regardless of CUR.0.1's outcome | **Done, 2026-10-02** (GL branch `feature/cur-1-1-jurisdiction-gh-gm`, commit `719628c`, local - not pushed). Found `MoneyTest.kt` already covered LRD/GNF/XOF at the `Money` level (including GNF/XOF's 0-decimal-place rounding) - only GHS/GMD were genuinely untested anywhere, and nothing existed at the `Company.create()` level for any of the five. Added one `CompanyTest.kt` case covering all five, deliberately paired with the existing `Jurisdiction.NG` (not a real GH/GM jurisdiction - see CUR.1.1's correction below). Full suite green, run via `gradlew test`, not assumed. |
| CUR.1.4 | New `docs/GH/GH_Tax_And_Currency_Settings.md` + `docs/GM/GM_Tax_And_Currency_Settings.md` (+ `.yaml`), mirroring the existing SL/LR/GN/CI/UK/IE/NG pattern - real, sourced corporate-tax/GST-VAT/payroll-levy figures, never fabricated | CUR.0.1 decided (Ghana/Gambia in scope) | **Parked - CUR.0.1 decided "hold," 2026-10-02.** Not started, and not to be started until a real paying tenant in Ghana or Gambia exists. |
| CUR.1.1 | Add `Jurisdiction.GH`/`Jurisdiction.GM` (two new enum constants, additive, no migration needed since nothing references them yet) | CUR.1.4 (real sourced tax docs must exist first), CUR.0.1 decided | **Parked - CUR.0.1 decided "hold," 2026-10-02.** Re-sequenced 2026-10-02 to depend on CUR.1.4, not the reverse - see that row's own history. Not started. |
| CUR.1.3 | WEB: add the decided currencies (CUR.0.1) to `AddCompanyForm.tsx`'s and `OnboardingWizard.tsx`'s duplicated `CURRENCIES` arrays | CUR.0.1 decided; CUR.1.1 only for any currency meant to pair with a GH/GM Company specifically (GHS/GMD could otherwise ship against an existing jurisdiction, mirroring CUR.1.2's own NG pairing, if that's ever a real combination) | **Parked - CUR.0.1 decided "hold," 2026-10-02.** Not started. |
| CUR.1.5 | Confirm and document CUR.0.2's recommendation (no FX prerequisite for a single-currency Company) as a settled decision, cross-referencing the pre-existing Group-reporting gap rather than duplicating it | CUR.0.2 | Paperwork only if the recommendation is accepted - no code change. Not yet done - low priority now that CUR.0.1 is "hold." |

### Explicitly out of scope here

- Building IAS 21 FX/exchange-rate support, or Group-level multi-currency consolidation - pre-existing, separately tracked gaps, not created or resolved by this item.
- Any school-billing-specific currency logic (e.g. a Fee Desk invoice line's own currency handling) - that's Education Runtime's own Fee Desk build, unscoped and untouched here.

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
- **2026-09-30 (CM)**: Unrelated to Wave 0/0R - a platform-wide data-quality
  fix surfaced while investigating the same SEV-1 (GL's `Jurisdiction` enum
  closed to `UK`/`IE`/`NG`/`SL`/`LR`/`GN`/`CI` in 2026-09-19; some
  `companies` rows still carried pre-closure free-text values, throwing
  `IllegalArgumentException` on `Jurisdiction.valueOf()` and 500ing that
  Company's `money-velocity`/`expense-velocity`/`sales-to-expense-ratio`
  endpoints). Found and fixed incrementally as GL/WEB reported individual
  crashes, then closed properly with a platform-wide audit at GL's request:
  `SELECT id, name, jurisdiction FROM companies WHERE jurisdiction NOT IN
  (...)` found exactly 4 bad rows total (`a0a54ea7` "QA Smoke Test Co UK",
  `1ba889dd` "CSC limited", `8ff04119` "理容やすらぎ", `13de72e4` "xyz"),
  all carrying the same stale `GB` value - no other free-text patterns
  (no "Sierra Leone"/"Liberia"/etc.) turned up. Also fixed two more `GB`
  rows found incidentally before the audit ran: `a1398b0d` "Prodeo Capital"
  and `2ee7984b` (renamed "Prodeo Trading" at the user's direct request -
  was a placeholder duplicate of the Tenant's own name "Prodeo Group",
  and had no `company_names` row in EA at all, added one). All 6 affected
  rows corrected `GB` -> `UK` via direct one-off `UPDATE`s (temporary RDS
  public access per the established procedure, each write confirmed with
  the user directly first, reverted immediately after). Re-ran the audit
  query after the final batch - zero bad rows remain. No code change was
  needed or made; the enum closure itself was correct and working as
  designed, this was purely stale legacy data predating it.
- **2026-10-01 (WEB session)**: Per direct user instruction ("everyone
  check their dependency-ordered backlog and start; register peer
  dependencies in coordination"), corrected two stale 0R.3 status entries
  above to "merged and deployed" (verified directly against the live
  production bundle, not assumed from the PR having been reviewed) and
  added three WEB/EA items to the "not yet waved" table that previously
  only existed in this session's own private memory: WEB's now-resolved
  CI/CD gap, the concurrent-Tenant-Membership onboarding gap, and the
  no-self-service-School-provisioning gap - all three surfaced during the
  past two days' incidents but weren't visible to the rest of the team
  until now.
- **2026-10-01 (IM session)**: Closed out Wave 2.1 - `RecordGoodsReceiptUseCase`
  generalized for non-PO receipts, mirroring the issue-side's own 2026-09-03
  precedent. Commit `31f3a3a`, 229 tests + integration pass. Unblocks SOP's
  Wave 3.1.
- **2026-10-01 (IM session, later)**: Decided 4.2 (Repairable needs no new
  IM location-state concept - the Bin/Transfer mechanism already fits) and
  proposed a recommendation for 4.1 (reuse `DAMAGE`, park the traceability
  gap) to SOP for confirmation, since it's a joint decision. Flagged a
  possible implication for 4.4 (may collapse into "no separate IM build" if
  Repairable posts the same crossing as Resaleable) pending SOP's
  confirmation. No code changes - decisions/investigation only.
- **2026-10-01 (IM session)**: Added a new "not yet waved" item (bulk
  low-stock listing) - direct user instruction via EA, who found the gap
  while scoping its own UC-BO03 work and was told this capability belongs
  in IM, not an EA-composed N+1 workaround. Verified directly: only
  `GET /items/{id}/inventory-levels` (per-item) exists; no bulk route.
- **2026-10-01 (IM session, incident)**: SOP found - while scoping an
  unrelated task - that PR #7's route restructuring broke every POP/SOP
  service-account call into IM (`/items/{id}/receive`/`/items/{id}/issue`
  404ing) since `038e53b` deployed, because those routes got nested under
  `/companies/{companyId}` with no un-scoped fallback and POP's/SOP's own
  `KtorImGateway`s still called the old flat paths. IM's own fault -
  confirmed directly against `Application.kt`, should have been caught
  before merging. POP and SOP each fixed their own gateway (POP:
  `purchaseOrder.entityId` as the real companyId; SOP: four call sites,
  `request.companyId`/`request.entityId` depending on the aggregate),
  both verified correct by IM, both added regression tests asserting the
  actual request URL (the gap response-parsing tests couldn't catch).
  SOP's fix: [commit 8b1226b](https://github.com/prodeo-group-dev/fish-sales-order-processing) on `fix/im-gateway-company-scoped-paths`, 291 tests green, handed to CM.
  **Incident closed, 2026-10-01 - full timeline confirmed by CM via real ECS image SHA + ECR push timestamps, not just commit merges**: start `038e53b` pushed 2026-09-30T05:23:08+01:00; POP's fix live 2026-10-01T07:12:04+01:00 (~25h49m); SOP's fix live 2026-10-01T07:25:03+01:00 (~26h02m) - closed as of SOP's deploy. Both fixes reviewed by CM before merge. **Handled entirely through peer `SendMessage` traffic with
  nothing written here until a direct instruction ("follow the prime
  directive, coordination") caught the gap** - correcting it now, this
  late, is itself the finding worth recording: real-time peer messaging
  is not a substitute for this file, even when everyone involved is
  actively coordinating well through other channels. Line 149 above
  (the "doesn't affect module-to-module crossings" claim - IM's own,
  commit `5d69e8f`) is the root miss: true for the EA-membership auth
  bypass, never re-examined against the separate URL-shape question PR #7
  actually changed. Open process question raised to the user by CM, not
  resolved here: whether cross-service route-shape changes need a
  contract-test or post-deploy smoke-test step before merge, given unit
  tests inside one repo structurally cannot catch a sibling repo's caller
  going stale - this is the second incident of that same root-cause
  shape (the first: the EA `/me` DTO drift hitting IM/POP/SOP
  independently).
- **2026-10-01 (WEB session)**: Per direct user instruction ("Glean from
  here to add to your backlog"), read a new local spec file
  (`C:\Users\femif\Downloads\FiSH-ER-Education-Runtime-Technical-Req-Spec-and-Use-Cases-v0.1.md`,
  230 requirements, not yet committed to this repo) and added five GL/SOP/EA
  cross-cutting items to the "not yet waved" table above: the missing
  event-bus architecture the spec's own FIN-INT contract assumes, a real
  currency conflict between the spec's required multi-currency school
  billing and the existing SLE-only Mano River decision (flagged, not
  resolved), a pass-through-liability CoA posting pattern GL hasn't been
  checked against, the offline cash receipt-number-range gap, and an EA
  role-mapping question. The ER-specific (non-GL-crossing) findings from
  the same document - new named markets (Ghana, The Gambia), the UK-later
  variant, and the formal FIN-INT event/API list refining Epic 0's existing
  generic rows - were logged instead in `ER/Principal/docs/The_Principal_Backlog.md`,
  per this document's own scope note that ER/EducationRuntime work belongs
  there. No code changed - documentation only.
- **2026-10-02 (SOP session)**: Built and deployed SOP's own sales
  performance report (`GenerateSalesPerformanceReportUseCase`,
  `GET /companies/{companyId}/sales-performance` - commit `412033a`,
  merged/deployed by CM, PR #12). Routine single-service work, no
  coordination row needed per this log's own carve-out. While scoping
  it, confirmed GL already owns Accounts Receivable aging
  (`AccountsReceivableAging`) and deliberately did not duplicate it in
  SOP - but found GL has no HTTP route exposing that computation at
  all. Added to the "not yet waved" table above for whenever a GL
  session is live; not actioned here since it's outside SOP's repo.
- **2026-10-02 (GL session)**: Closed the gap SOP flagged above - new
  `ComputeAccountsReceivableAgingUseCase` + `POST /companies/{companyId}/accounts-receivable-aging`
  (commit `d29ce6d`, local, handed to CM), returning the full bucketed
  breakdown `ComputeCustomerBalancesUseCase` collapses to a scalar.
  Claimed this log's row before starting (GL's first ever, per IM's
  2026-10-01 finding that GL had never claimed one despite qualifying
  work) and released it on completion. AP's identical gap
  (`AccountsPayableAging`/`ComputeVendorBalancesUseCase`) left open,
  not actioned in this pass.
- **2026-10-02 (GL session, continued)**: Built the AP mirror
  (`ComputeAccountsPayableAgingUseCase` + `POST /companies/{companyId}/accounts-payable-aging`,
  commit `5c5c8cb`, local, handed to CM) per direct user instruction.
  Claimed and released a second coordination row for this follow-up.
  CM caught a near-collision while reviewing: the user had separately
  instructed CM to build this same route directly, but CM checked this
  log first, found GL's claimed row, and reviewed GL's implementation
  instead of duplicating it - exactly the scenario this log exists to
  prevent.
- **2026-10-02 (WEB session)**: Per direct instruction to Scope/Plan/Task/
  Order-by-dependency the multi-currency conflict flagged 2026-10-01,
  read `Money.kt`/`Company.kt`/`TenantRoutes.kt`/`jurisdiction.kt` and
  WEB's `AddCompanyForm.tsx`/`OnboardingWizard.tsx` directly before writing
  anything. Found the conflict was narrower than first flagged - `Money`/
  `Company` already accept any ISO currency with no code-level gate; the
  real gates are WEB's hardcoded `CURRENCIES` dropdown (missing GHS/GMD/
  LRD/GNF/XOF, but already has NGN/USD) and, more significantly, a
  previously-unflagged blocker: `Jurisdiction` is a closed 7-value enum
  with no `GH`/`GM` at all, so a Ghana/Gambia Company can't be created
  regardless of currency. Added a "Multi-currency conflict detail" section
  above with four blocking decisions (CUR.0.1-0.4) and five
  dependency-ordered tasks (CUR.1.1-1.5) - no code changed, decisions
  still needed from the user. Replaced the old one-line currency row in
  the "not yet waved" table with a pointer to the new section.
- **2026-10-02 (WEB session, continued)**: Per direct instruction to
  actually execute the task list rather than leave it as open decisions,
  resolved CUR.0.4 directly (clean engineering split, no business
  judgment needed) and built CUR.1.2 (GL branch
  `feature/cur-1-1-jurisdiction-gh-gm`, commit `719628c`, local, full
  suite green via `gradlew test`). **Attempting CUR.1.1 surfaced a real
  correction to this doc's own prior task ordering**: `jurisdiction.kt`'s
  KDoc defines `Jurisdiction` as backed by real sourced tax docs for
  every value, so adding `GH`/`GM` before `docs/GH/`/`docs/GM/` exist
  would violate the enum's own documented invariant - re-sequenced
  CUR.1.1 to depend on CUR.1.4, not the reverse. CUR.0.1 (which
  currencies/when) remains the one genuine open business decision -
  everything else in this section is now either done, decided, or
  correctly gated on that one answer.
- **2026-10-02 (WEB session, continued)**: CUR.0.1 decided directly by
  the user - hold all five currencies (GHS/GMD/LRD/GNF/XOF), none onboard
  now, revisit per-market once a real paying tenant needs one. CUR.1.1,
  CUR.1.3, and CUR.1.4 all marked parked, not started, per that decision.
  The "Multi-currency conflict detail" section is now fully resolved:
  CUR.0.1-0.4 all decided, CUR.1.2 built and tested, CUR.1.1/1.3/1.4
  deliberately parked, CUR.1.5 still open (low priority).
- **2026-10-03 (GL session)**: Renamed GL's `Creditor` domain class to
  `Supplier`, per a decision confirmed with Femi and relayed via WEB
  while it was building the AR/AP aging screens. `domain/purchasing/creditor.kt`'s
  own KDoc already framed itself as "the Debtor side"'s mirror but named
  its class after the *state* word (Creditor) instead of the
  *relationship* word (matching `customer.kt`'s own Customer/Debtor
  pattern, verified directly before acting) - and POP/SOP/WEB already
  call the same real-world entity "Supplier" everywhere a human sees
  it, with "Vendor" as a third synonym live in GL's own route/DTO
  names until now. Done as one full, consistent pass (domain class,
  repositories, use cases, routes, wire field names, route path) rather
  than a staged rollout, since Femi put every other peer session on
  hold until this landed and was tested - no benefit to a mixed interim
  state with nobody calling the old shape concurrently. GL commit
  `7d7c79e`, local, handed to CM. Full suite green (compile + test, 0
  failures).

  **Wire shape change, needs POP/WEB lockstep before CM deploys**:
  - Route `POST /companies/{companyId}/vendor-balances` ->
    `/supplier-balances`.
  - JSON field `vendorId` -> `supplierId` in
    `RecordSupplierObligationRequestDto`/`RecordSupplierPaymentRequestDto`
    (bodies POP POSTs to `/purchasing/record-obligation`/`/record-payment`).
  - JSON field `creditorIds`/`creditorId` -> `supplierIds`/`supplierId`
    in `ComputeSupplierBalancesRequestDto`/`SupplierBalanceDto`/
    `ComputeAccountsPayableAgingRequestDto`/`SupplierAgingDto` (WEB's
    `agingReports.ts` consumes these).

  **Deliberately left unchanged**: the physical Postgres table name
  stays `"creditors"` (`SuppliersTable`'s `Table("creditors")`) - a
  live table rename is its own separate ForceNew-shaped risk, deferred
  to `docs/Downtime_Maintenance_Backlog.md`, same treatment as the
  Education Runtime rename's AWS/DB resource names. `DimensionType.VENDOR`
  also stays unchanged - it tags already-posted `JournalLine.dimensions`
  data, a different risk category from the in-process class/DTO renames
  (renaming it would change the persisted dimension key for any journal
  line tagged before this rename).

  POP and WEB were both notified directly with this exact before/after
  shape ahead of the rename landing, per "coordination is the prime
  directive" - not left to discover it from the diff.
