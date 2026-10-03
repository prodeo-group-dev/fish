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



| General Ledger - GL | 2026-10-03T00:00:00Z | Creditor→Supplier domain rename, confirmed by Femi (relayed via WEB while building AR/AP aging screens): `domain/purchasing/creditor.kt`'s own KDoc already frames itself as "the Debtor side"'s mirror but named its class after the *state* word (Creditor) instead of the *relationship* word (Customer's own pattern) - and POP/SOP/WEB already call the same real-world entity "Supplier" everywhere a human sees it, with "Vendor" as a third synonym live in GL's own route/DTO names. Decision: rename to **Customer/Supplier** as the relationship pair, "Creditor"/"Debtor" reserved as prose/state terms only. **Three-tier plan**: (1) pure Kotlin rename (classes/files/functions, zero wire impact) - doing now; (2) wire-breaking rename (`/vendor-balances` route path, `vendorId`/`creditorId`/`creditorIds` JSON field names in `RecordVendorObligationRequestDto`/`RecordVendorPaymentRequestDto`/`ComputeVendorBalancesRequestDto`/`VendorBalanceDto`/`ComputeAccountsPayableAgingRequestDto`/`VendorAgingDto`) - code will be ready today but **NOT deployed until POP and WEB confirm their own calling-code updates are ready**, mirroring the suspenseAccountId precedent; (3) physical DB table/column names (`creditor_tables.kt`'s underlying Postgres table) - deliberately left unchanged, deferred to `docs/Downtime_Maintenance_Backlog.md` same as the Education Runtime rename's AWS/DB resource names. POP is a live caller of `/purchasing/record-obligation`/`/record-payment` (vendorId field) and must update in lockstep; WEB is a live caller of `/vendor-balances`/`/accounts-payable-aging` (creditorId/creditorIds fields, `agingReports.ts`, branch `feature/ar-ap-aging-screens`). | GL: `domain/purchasing/creditor.kt`→`supplier.kt`, `ComputeVendorBalancesUseCase`, `RecordVendorObligationUseCase`/`RecordVendorPaymentUseCase`, `VendorBalancesRoutes.kt`, `RecordVendorObligationAndPaymentRoutes.kt`, `Dtos.kt`; POP: its GL-calling gateway for record-obligation/record-payment; WEB: `agingReports.ts` |

## Format for a new row

```
| <session name from ListAgents> | <ISO 8601 timestamp> | <one-line description> | <paths/repos, or "TBD"> |
```
