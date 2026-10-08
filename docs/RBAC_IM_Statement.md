# RBAC: Inventory Management (IM) statement for the application round

**Owner:** IM session. **Status:** statement of current rules and plan, docs only, 2026-10-08. **Written against:** IM `origin/master` `17afdd0` (IM PR #8: goods-issue idempotency and Company-scoped ledger postings, live as task definition :26). Every claim below was read from that code; nothing here is from memory. No code or authorization change has been made (RBAC freeze). Answers CM's request for `docs/RBAC_SPUTO.md` v0.2 section 5, step 6.

---

## 1. IM's current authorization rules, as the code does them

| Topic | What IM does today | Where |
|---|---|---|
| Identity | JWT, RS256, verified against the shared Cognito JWKS. Only the `email` claim is used (no `sub`). The `cognito:groups` claim is also read. Three named providers are tried **in this order**: human (`IM_JWT_AUDIENCE`), POP service (`IM_JWT_SERVICE_AUDIENCE_POP`), SOP service (`IM_JWT_SERVICE_AUDIENCE_SOP`). | `Auth.kt` `installImJwtAuth`, `imAuthenticated` |
| Human decision | Per route, with the **Company from the URL path**: `authorizeImForRead` (needs READ) or `authorizeImForWrite` (needs WRITE). IM calls EA `GET /me` with the caller's own token on every request, takes the Membership in IM's one configured Tenant (`IM_EA_TENANT_ID`), and requires `accessLevelAt(company) >= minimum` **and** `"IM" in grantedModulesAt(company)`. A Company absent from `/me` is NONE. An Owner Admin listed for a Company with no assignment gets the READ floor but no module, so is refused. No Membership in the Tenant is 403. EA unreachable is 503 (fail closed). | `Auth.kt` `ImMembershipAuthorizer`, `authorizeIm`; `ea_membership_gateway.kt` `accessLevelAt` |
| What needs what | **READ:** GET items, item, stock velocity, inventory levels, pending adjustments, warehouses, zones, bins, location assignments. **WRITE:** everything else: create Item, selling price, goods receipt, goods issue, bin transfer, create adjustment, stock count, replenishment policy, create warehouse/zone/bin, assign location. **APPROVE and ADMIN levels are never checked**: a caller with them gets nothing extra. | the `*Routes.kt` files |
| Approvals | Approve and reject of an adjustment additionally require the Cognito group **`StoreManager`** on the human token. It is a **User Pool group, not an EA role**, and is **not per Company**. A stock count only needs WRITE; it raises a pending adjustment that a StoreManager then approves. Service tokens carry no group, so they are excluded. | `Roles.kt` `requireStoreManager`; `AdjustmentAndStockCountRoutes.kt` |
| Service accounts | A POP or SOP token (own audience) is marked `isServiceAccount` and **skips the whole EA check on every route that calls `authorizeIm`**: no level, no module, no Membership. Nothing binds the token to a Tenant or Company, and nothing limits it to the few routes POP and SOP actually use (they can create Items, warehouses, adjustments, receipts, issues). Permanent by decision (2026-09-16 design note). | `Auth.kt` `authorizeIm`; `VerifiedIdentity.kt` |
| Ownership of records | `requireOwnedBy` (404, same answer as "missing") on every route that takes an Item, Warehouse, adjustment or bin: Item routes (get, velocity, selling price, receive, issue, transfer, adjustments, stock count, replenishment, levels, location assignments), adjustment approve and reject (via the adjustment's Item), create zone (via its Warehouse), create bin (via zone then Warehouse), assign location (Item, and the bin's Warehouse). Lists are filtered with `findAllByEntity` / by walking the caller's own Warehouses. IM has **no** get/update/delete by zone id or bin id, so the shape POP found in its supplier routes does not exist for Locations and Bins. **One gap, see 2.3:** a `binId` in a request **body** on goods receipt. | `RouteHelpers.kt`, `ItemRoutes.kt`, `LocationRoutes.kt`, `AdjustmentAndStockCountRoutes.kt` |
| Who did it | **IM records no actor anywhere.** Goods receipt and issue confirmations, adjustments (created, approved, rejected) and idempotency keys carry no email or user id. Only the GL journal carries whatever GL itself records. | domain types, `exposed_*` repositories |
| Outbound | IM calls GL as itself with a Cognito service account, and posts to the **Company that owns the Item** (since PR #8). The `X-Tenant-Id` sent to GL is still one deploy-time value (`IM_GL_ENGINE_TENANT_ID`). | `ktor_gl_engine_gateway.kt` |

## 2. Survey findings that name IM, re-verified against master

**2.1 F1 (fail-open verifiers). Present in the code, not exploitable in IM as built, still worth fixing.** `Application.kt` (`imModule`) calls `installImJwtAuth(verifier, popServiceVerifier ?: verifier, sopServiceVerifier ?: verifier)`, and `buildJwksServiceVerifierForPop/Sop()` return null when the audience variable is unset, so the fallback is real. CM verified all service audiences are set in production. **Why it does not open a hole today:** Ktor tries the providers in the listed order and the human provider is first, so a human token authenticates as a human (`isServiceAccount = false`) and the later providers are never reached. Evidence: the end-to-end tests build the module with **one** verifier for all three providers and a human with no Membership still gets 403 (`ApplicationEndToEndTest` lines 185, 198, 220). It rests on that ordering, which no test pins and no comment states. Fix is T1.

**2.2 F3 (create and approve by the same person). True in IM, in a different shape.** The approver is a pool-wide group, nothing compares creator with approver, and **nothing records either**. Also: `requiresApproval` is a field the caller sends (default true). A caller sending `false` gets an adjustment in status `NOT_REQUIRED`, but the approve route only accepts `PENDING_APPROVAL`, so **such an adjustment can never be posted**. It is a dead-end state, **not** a bypass; I checked this because it looked like one.

**2.3 NEW, not in the survey: unvalidated `binId` on goods receipt.** `POST .../items/{id}/receive` reads an optional `binId` from the body and the use case creates a stock balance for (that Item, that bin) on first receipt, without checking the bin exists or belongs to the path Company. A WRITE caller at Company A can therefore create a balance row pointing at another Company's bin. Issue is safe (it requires an existing balance) and transfer is safe (only bins already assigned to the Item, which are ownership-checked when assigned). Same class as POP's supplier gap. It is an ownership bug fix, not an authorization-model change, but I will not touch it during the freeze without CM's word.

**2.4 NEW: WRITE alone can direct postings.** A WRITE caller chooses `contraAccountId` on goods receipt, goods issue and adjustment approval (any account GL accepts for the Company), and chooses the asset and cost-of-sales accounts when creating an Item. Receipts, issues and opening stock post to GL immediately on WRITE with no second person. Femi's principle ("the writing into financial data is wrong") applies here; whether stock movements need approval is a policy question I am not assuming the answer to (see section 4).

## 3. Gaps against R1-R13 and tasks T1, T4, T11

| Requirement | IM today | Gap |
|---|---|---|
| R1 definitions | Only READ and WRITE are used | APPROVE and ADMIN unused, so R1 changes nothing until T5a lands |
| R2 approvals | Pool-wide group; no actor; no creator/approver rule; contra override open to WRITE | Yes (T11) |
| R3 thresholds/policy | `requiresApproval` is caller-supplied; no threshold in IM | Define or remove (see 4.5) |
| R6 fail closed | `?: verifier` fall-backs exist | Yes (T1), latent |
| R7 scoped service credentials | Blanket bypass, no Company or Tenant binding, all routes | Yes (T15, plus a per-service route allow-list) |
| R8 missing Company = NONE | Already NONE | **None.** T4 is already true in IM |
| R9 canonical email | Whatever the token says; IM never matches by email | None in IM (EA matches); needs `sub` or EA `userId` for R10 |
| R10 audit | No actor anywhere | Yes (T17, and prerequisite for T11) |
| R11 WEB | Not IM's | Not IM |

| Task | IM work | Estimate | Blocked on |
|---|---|---|---|
| **T1** fail-open | Make the two service audiences required at start-up (or register deny-all providers), remove `?: verifier`, add a test that pins the order and a start-up test for the missing variable. | about 0.5 day plus HIGH review | nothing; CM's go |
| **T4** missing Company = NONE | Already behaves that way; add one test that pins it. | about 0.25 day | nothing |
| **T11** approvals | (a) record the acting identity on create, approve and reject (migration V10: created_by, decided_by, decided_at; actor = EA `userId` from `/me`, falling back to email); (b) creator is not approver, except the Owner, whose self-approval is allowed and flagged in the record (D6); (c) replace the `StoreManager` group by the EA approve capability at that Company. | (a) and (b) about 1.5-2 days; (c) about 0.5 day | (a)(b) CM's go (they change who may approve); (c) **T5a** (the capability set) |
| 2.3 bin ownership | Check the bin exists and belongs to the path Company on receive; 404 like missing. | about 0.25 day | CM's go |

**Suggested order for IM:** T1, then T4 pin, then 2.3, then T11 (a)(b), then T11 (c) after T5a, then the per-service route allow-list and Tenant derivation with T15.

## 4. Objections and things the SPUTO misses

1. **`StoreManager` is wider than it looks.** It is a pool-wide group, so a StoreManager who also holds WRITE at two Companies can approve write-offs at both, and the group is granted outside EA where nobody sees it. Moving approval to an EA capability per Company (T11 c) fixes both. Until then, nothing in EA shows who is a StoreManager.
2. **Not just adjustments.** F3 names IM adjustments, but goods receipt, goods issue and opening stock also post money on WRITE alone. **Question for Femi:** is an operational stock movement meant to need an approver (slows every sale), or only write-offs and counts (today's meaning)? I will implement whichever he decides; I will not guess.
3. **Contra account and Item account mapping should be configuration, not WRITE.** Suggest R3 covers them: the cost-of-sales and inventory asset accounts on an Item, and any override of the contra account, need ADMIN (or come only from a service principal). Needs Femi's yes.
4. **Service principals need a route allow-list, not only a Tenant.** POP needs issue (Return Outwards); SOP needs availability read, issue, receipt and adjustment create. Everything else could be refused for them. R7 mentions endpoint sets; IM can supply the exact lists.
5. **`requiresApproval`** should be removed or become a server-side threshold (R3); a caller-supplied flag that makes an adjustment unpostable is a trap, not a control.
6. **IM is single-Tenant by configuration** (`IM_EA_TENANT_ID` and `IM_GL_ENGINE_TENANT_ID`). It cannot serve a second Tenant until T15; a Company under another Tenant already fails cleanly at GL.
7. **Idempotency keys are not attributed.** When T17 defines the audit record, the key table should carry the actor too; today it carries none.

## 5. What IM needs from others

- **EA:** the shape and name of the capability set (T5a) and an `approve` capability per module at a Company; confirmation that `/me` `userId` is stable and may be recorded by services as the actor; an `isOwner`-at-Company signal for the D6 self-approval flag (today `isOwnerAdmin` is per Membership).
- **CM / Femi:** go on T1, T4 and the bin fix; Femi's answers to 4.2 and 4.3.
- **GL / EA (T15):** how a service learns a Company's Tenant (GL option A or B, EA lookup route), on hold with the freeze.
- **POP / SOP:** nothing now; later, agreement on the route allow-lists in 4.4.

*Verified in the code on 2026-10-08 by reading `Auth.kt`, `Roles.kt`, `VerifiedIdentity.kt`, `ea_membership_gateway.kt`, `ItemRoutes.kt`, `LocationRoutes.kt`, `AdjustmentAndStockCountRoutes.kt`, `RecordGoodsReceiptUseCase.kt`, `TransferStockUseCase.kt`, `CreateInventoryAdjustmentUseCase.kt`, `inventory_adjustment.kt` and the end-to-end tests.*
