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
| General Ledger - GL | 2026-10-06 | Adding a nullable `cashAccountId` to `GET /companies/{companyId}/sales-posting-context` (additive; ASSET account code "1000", resolved exactly as `CreateSalesInvoiceUseCase` does for cash sales, null if not configured), for SOP moving cash sales to SOP (normal sale + immediate collection). **Second item, same day (SOP request):** also adding `grossAmount`/`vatAmount` (plain decimals, additive, always present) to the `POST /sales/record-sale` response so SOP can collect exactly the AR GL debits (net + VAT); same release order (SOP declares nullable first, then GL). **Third item, 2026-10-06 (WEB request, Femi agreed):** a read route `GET /api/companies/{companyId}/vat-categories?asOf=` returning the VAT categories and rates valid for that Company's jurisdiction, so WEB's Sales form can send the per-line `vatCategory` SOP requires (WEB then declares the JSON strictly). **Femi chose Option B (2026-10-06, via WEB): VAT rates become DATA** - a `vat_rates` table (jurisdiction, category, rate, effective_from, plus a `verified` flag so a seeded schedule is not live until its rates are confirmed against a primary tax source) read through a repository, `VatRateSchedule.forJurisdiction` becomes a lookup, seeded IE + UK (verified) and SL (15% GST, NOT verified/live until Femi confirms); LR/GN/CI/NG rows are NOT built until Femi approves. Record-sale/obligation routes switch from the code constants to the repository. **Depends on peer: SOP** (declares the new field strictly in its mirror DTO and ships its side only after GL's deploy; SOP is also reading `GET /companies/{companyId}/sales-invoices` with its service account, which GL confirms is accepted for READ). CM merges/deploys. | GL: `ComputeSalesPostingContextUseCase`, `SalesPostingContextRoutes`, `RecordSaleUseCase`, `RecordSaleAndCollectionRoutes`, new VAT-categories use case + route, `VatRateSchedule`/`VatRateRepository` + `vat_rates` migration (V30), `RecordSaleAndCollectionRoutes`/`RecordSupplierObligationAndPaymentRoutes` lookups, `Application.kt`, `Dtos.kt` (`SalesPostingContextResponseDto`, `RecordSaleResponseDto`), their tests; SOP: its `SalesPostingContext` mirror DTO; WEB: Sales form `vatCategory` picker |



## Format for a new row

```
| <session name from ListAgents> | <ISO 8601 timestamp> | <one-line description> | <paths/repos, or "TBD"> |
```
