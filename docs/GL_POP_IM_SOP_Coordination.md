# GL / POP / IM / SOP Coordination Log

**Trigger:** direct instruction, 2026-09-28 — "There should be coordination
between GL, POP, IM, SOP always in every build." Modeled directly on
`Infrastructure/COORDINATION.md` and `ER/Principal/EducationRuntime/COORDINATION.md`,
which already solved this same "more than one session can independently
pick up overlapping work" problem for their own repos — this file is the
same protocol, scoped to the four services that sit on either side of the
Purchase-to-Pay / Inventory / Order-to-Cash cycle and its reversals
(`docs/Purchase_Inventory_Sales_Cycle_And_Reversals_Scoping.md`,
`docs/GL_POP_IM_SOP_Backlog.md`).

**Why a cross-repo file, not one per repo:** GL/POP/IM/SOP are four separate
git repos (submodules of `FiSH/`), but the work that actually needs
coordinating is precisely the work that *crosses* them — a GL-crossing
posting interface, an EA-membership authorization pattern duplicated across
services, or a step in the shared cycle. A single shared log at the `FiSH/`
level (alongside the backlog it coordinates against) is more useful here
than four independent per-repo logs that can't see each other.

**When this applies** — before starting non-trivial work on any of:
- A GL-crossing posting interface (any `Record*UseCase` on GL's side, or
  the corresponding call site in POP/IM/SOP).
- An EA-membership authorizer (`{Service}MembershipAuthorizer` /
  `EaMembershipGateway`-consuming code) in any of the four services.
- Anything in `docs/GL_POP_IM_SOP_Backlog.md`.
- Anything else that changes a cross-service assumption one of the other
  three services' code currently relies on.

Routine, single-service work (a new IM report, a POP-only UI tweak, a
GL-only reporting feature with no cross-service crossing) doesn't need a row
here — this log is for the boundary work specifically, not a substitute for
each service's own normal development.

**CM, added 2026-09-28** ("Always coordinate with POP, IM, GL, and CM"):
once a fix on this backlog is ready to actually merge/deploy, that step
crosses into Configuration Manager CM's own established territory
(`FiSH/CLAUDE.md`'s Configuration Management section) — check
`Infrastructure/COORDINATION.md` and loop CM in before deploying, the same
as any other infra/Jenkins/secrets-touching change. This file stays scoped
to GL/POP/IM/SOP's own application-code coordination; it doesn't replace
CM's log, it hands off to it at the deploy boundary.

**Protocol** (identical to Infrastructure's/Education Runtime's own):
1. Before starting, check the Active table below. If an entry overlaps what
   you're about to do, message that session first (`ListAgents` to find it,
   `SendMessage` to reach it) rather than proceeding blind.
2. Add your own row when you start, and **push it as its own tiny commit
   immediately** — before doing any of the actual work, not bundled with
   your eventual change. A claim that only reaches the remote alongside the
   finished work arrives too late to prevent the exact collision this file
   exists to catch.
3. Remove **only your own row** when you're done — whether that's a real
   finish (committed, pushed, merged/deployed) or an abandonment. Never edit
   or remove another session's row. If a row looks stale (the session that
   wrote it is long gone, or the work clearly landed already), ask the user
   rather than deleting it yourself.
4. When you ship something that closes or advances an item in
   `docs/GL_POP_IM_SOP_Backlog.md`, update that file's Status column in the
   same commit (or immediately after) so the backlog stays accurate — this
   log is about *not colliding while working*, the backlog is about *what's
   actually done*, and the two drift apart fast if only one gets updated.
5. This file is git-tracked on purpose — visible in history and in any PR
   that touches it, and it survives both sessions not being live at the same
   moment (unlike a `ListAgents` check alone).

This is a "please look before you leap" register, not a hard lock — two
sessions can still start within seconds of each other and both see an empty
table. It shrinks the collision window; it doesn't eliminate it.

## Active

| Session | Started (UTC) | Working on | Files/areas |
|---|---|---|---|
| FiSH+ER WEB | 2026-10-01T02:30:00Z | Picking up the "start your own Tenant while staying staff elsewhere" backlog item (not yet waved - see the "not yet waved" table) per next-dependency-ordered-item instruction, 2026-10-01 — **BLOCKED on EA confirming `OnboardTenantUseCase`/`RegisterCompanyUseCase` don't assume a brand-new User with zero existing Memberships.** Not yet started on the WEB side; confirming with EA first before building the `CompanyPickerScreen`/`TenantDashboard` entry point. | WEB: `CompanyPickerScreen.tsx`/`TenantDashboard.tsx` (new entry point, TBD exact shape); EA: `OnboardTenantUseCase`/`RegisterCompanyUseCase` (readiness confirmation only, no known change needed yet) |
| Enterprise Administration - EA | 2026-10-04 (updated; first registered by CM 2026-10-04) | **Omniview v2: EA-side BUILD, resumed by Femi to the EA session 2026-10-04 ("Resume the Omniview build"; CM has not yet received that from Femi in its own session, so CM's lane and the Omniview session's own code stay on hold until he tells them).** Local isolated worktrees only; CM merges, nothing pushed by EA. Order: (1) consent records, texts and routes (migration V18, must merge AFTER the registration fix's V17), (2) support-route edge protections, (3) GL-only consenting-tenants route with a service-principal validator that fails closed, (4) support relay routes against a fake Omniview gateway. **Release order, set by CM: the two EA security fixes (registration 18edbf4, invite guard 668c6b5) ship FIRST as their own release after Femi's read-only SQL pack (A, B, D, E, F); the Omniview branches wait behind them.** Depends on peers: CM (merge/deploy and release order; infra and applies on hold pending Femi in CM's session: EA->Omniview Cognito client and private path, EA_JWT_SERVICE_AUDIENCE_GL, SNS alert path), OmniView (private API, SRS 13.2, already confirms Draft 3 section 2; its own build waits on CM), GL (consenting-set call shape and its own service identity at EA), WEB (widget and consent screens, nothing claimed yet), Femi (open decisions D5 formal answer, D34, D36, D38, D9/D33; the SQL pack). Consent wording is PLACEHOLDER text and must not be shown to real tenants until D9. | EA repo only: new migration V18, new consent/relay code and tests under EA/src on local branches; docs/Omniview_v2_Backlog.md rows 7B.7 and 8B.1 (claimed); no shared checkout touched |
| Sales Order Processing - SOP | 2026-10-06T00:00:00Z | **Emailing a sales invoice to a customer as a PDF** (Femi's decision 2026-10-06, relayed via WEB; scope doc `WEB/docs/WEB_Invoice_Email_Scope.md` on branch `docs/invoice-email-scope`). Step 1: accept/amend the draft contract in writing, then build send + list routes, server-side PDF, SES raw-message sending, audit, rate limit. Invoice source decided: both - GL `SalesInvoiceRecord` for CASH invoices (read via GL), SOP `SalesOrder` for CREDIT sales (using the INV-xxxxxxxx number WEB already shows). **Peer dependencies:** CM (SES sender identity, `ses:SendEmail`, `SOP_NOTIFICATION_FROM_EMAIL` - first blocker for any real send); GL (SOP will read GL's existing `GET /companies/{companyId}/sales-invoices` with its service account and filter by number - no GL change needed for email; the Company name for the PDF comes from the caller's EA `/me` company entry, not GL; Reply-To = the signed-in sender's own email, since EA holds no company email); WEB (screen built against the FINAL wire contract sent 2026-10-06). **Added 2026-10-06, Femi: cash sales move to SOP too** (`POST /api/sales` gains `saleMethod` CASH|CREDIT; CASH = sale + immediate collection, real invoice number, paid state) - **BLOCKED on GL**: needs a nullable `cashAccountId` (ASSET code 1000) added to `GET /companies/{companyId}/sales-posting-context`; no GL session was live on 2026-10-06 to receive the ask. WEB must not move its cash path until SOP says the route is deployed; GL's legacy `create-invoice` retires only after that. | SOP: new email use cases/routes/PDF renderer (not started); GL: possibly a by-number read; Infrastructure: `sop.tf` sender (CM's) |
| Inventory Management - IM | 2026-10-07T00:00:00Z | **IM goods-issue idempotency (P0)**, per `docs/IM_Goods_Issue_Idempotency_SPUTO.md` (SOP's draft, fish PR #136), Femi's go 2026-10-07 with decisions: **D1 explicit `Idempotency-Key` header, NOT `salesOrderReference`** (verified: POP's Return Outwards reference is `{purchaseOrderId}#{lineIndex}`, so a PO line can legitimately be returned more than once); **per-Item advisory lock added in the same pass** (IM finding not in the SPUTO: `Item` saves are an absolute overwrite with no version/lock, so concurrent issues with DIFFERENT keys can both pass the on-hand check, both post to GL, last write wins); receipt side stays PARKED; 30-day key retention. Building SPUTO T1-T4 + T7 on a local IM branch, handed to CM for review/push. **Peer dependencies:** SOP forwards a per-line key (T5, SOP's own, after IM ships) and POP forwards its own for Return Outwards (T6); CM review/push/deploy; GL's `Idempotency-Key` on `inventory/record-issue` already exists (verified in `RecordInventoryReceiptAndIssueRoutes.kt`) so no GL change needed. Also claimed: drafting `docs/IM_Playbook_Draft.md` (docs only, FiSH repo). | IM: new `idempotency_keys` migration, `RecordGoodsIssueUseCase` + goods-issue route, `ktor_gl_engine_gateway.kt` (forward derived key to GL), tests; docs: `docs/IM_Playbook_Draft.md` |
| General Ledger - GL | 2026-10-08 | **Docs only, CM's request for the RBAC SPUTO:** a short written statement of two held options (service accounts omitting `X-Tenant-Id`; a Company-to-Tenant read route) with their risks, in a new `docs/GL_Tenant_Header_Service_Account_Options.md`. Nothing built; both options are on hold under CM's RBAC freeze. **Depends on peer:** CM (RBAC SPUTO), IM (the question that raised it). | New `docs/GL_Tenant_Header_Service_Account_Options.md` only |

| Inventory Management - IM | 2026-10-08T00:00:00Z | **URGENT (Femi 2026-10-08): IM posts every receipt, issue and adjustment to ONE GL Company** (deploy-time `IM_GL_ENGINE_COMPANY_ID`), not the Item's own Company, so a second Company's stock never reaches its own ledger. Read from code (ItemRoutes.kt receive/issue, AdjustmentAndStockCountRoutes.kt approve), not yet observed live. **Phase 1 (building now, IM checkout, branch `fix/im-post-to-item-company`, stacked on `feature/goods-issue-idempotency` c0cf5be because both touch ItemRoutes.kt):** post to `Item.entityId` (= the GL CompanyId since 0R.0.1), drop the env value; existing Items are unaffected because V8 backfilled their entity_id to the same Company the env names. Works for every Company under IM's configured Tenant (GL confirmed). **Phase 2 (not started):** the GL `X-Tenant-Id` is also one deploy-time value (`IM_GL_ENGINE_TENANT_ID`), so a Company under another Tenant is still refused; needs a Company-to-Tenant lookup. **Peer dependencies:** CM review/push/deploy and ordering against the idempotency branch; GL/EA for the Company-to-Tenant lookup (Phase 2); POP, who has the same pattern at `PurchaseOrderFulfillmentRoutes.kt:229` (`fetchPurchasePostingContext(glEngineCompanyId)`) and must check their own; CM is asking every peer whether their checkout has the same gap. | IM: `ItemRoutes.kt`, `AdjustmentAndStockCountRoutes.kt`, `Application.kt`, tests |

| Purchase Order Processing - POP | 2026-10-08T00:00:00Z | **(1) POP posts to the PO's own Company, not a deploy-time one** (IM's sweep via CM, confirmed in POP code): match, pay and return-dispatch fetched the GL posting context and posted with `POP_GL_ENGINE_COMPANY_ID`; now they use the authorized path Company, and the env var is no longer read. Not an authorization change. **(2) T6, Return Outwards dispatch idempotency** (contract final per IM, IM :26 live 2026-10-08): send `Idempotency-Key = return-outwards:{companyId}:{returnOutwardsId}` on IM's issue call, store the IM journal-entry id as a posted marker (new migration), add a retry path for a DISPATCHED-but-unposted return, close the concurrent-dispatch race. **Peer dependencies:** IM (real-token verification of its side - POP will NOT release T6 until IM confirms it, or CM says so); CM (review, push, deploy); GL (none: POP only changes which Company id it already sends). | POP: `PurchaseOrderFulfillmentRoutes.kt`, `Application.kt`, `DispatchReturnOutwardsUseCase`, `ReturnOutwards` + new migration, `im_gateway.kt`/`ktor_im_gateway.kt`, tests |

## Format for a new row

```
| <session name from ListAgents> | <ISO 8601 timestamp> | <one-line description> | <paths/repos, or "TBD"> |
```
