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
| Sales Order Processing - SOP | 2026-10-01T04:00:00Z | All three items this row was tracking are done and merged (Wave 5.1 `340f42e`, Wave 5.2 `15fcf8c`, Wave 3.1 `23e08aa` - PRs #10/#11, plus a follow-up test fix exposed only by merging the two waves together, `905951c` on `feature/wave-3.1-returns-inventory-crossing`, flagged to CM since origin/master's own merge commit landed without it). Row kept one more cycle only to flag that fix - safe to remove once CM confirms it's pulled in. | SOP: done, see commits above |
| FiSH+ER WEB | 2026-10-01T02:30:00Z | Picking up the "start your own Tenant while staying staff elsewhere" backlog item (not yet waved - see the "not yet waved" table) per next-dependency-ordered-item instruction, 2026-10-01 — **BLOCKED on EA confirming `OnboardTenantUseCase`/`RegisterCompanyUseCase` don't assume a brand-new User with zero existing Memberships.** Not yet started on the WEB side; confirming with EA first before building the `CompanyPickerScreen`/`TenantDashboard` entry point. | WEB: `CompanyPickerScreen.tsx`/`TenantDashboard.tsx` (new entry point, TBD exact shape); EA: `OnboardTenantUseCase`/`RegisterCompanyUseCase` (readiness confirmation only, no known change needed yet) |
| Inventory Management - IM | 2026-10-01T03:30:00Z | Building step 3 of `docs/Opening_Figures_CSV_Upload_DDD_Design.md` (Stock) per GL's handoff (steps 1-2 done) and the design doc's own build order. Building `RecordOpeningStockUseCase` (§4.1) now. **BLOCKED on GL generalizing `RecordInventoryReceiptUseCase` to accept a caller-supplied `JournalSource`** - confirmed directly, `Request` has no such field today, same hardcoded-source gap GL already fixed on `RecordOpeningBalanceUseCase`/`CreateFixedAssetUseCase` (and the identical gap POP independently found on `RecordVendorObligationUseCase` for their own AP step). Posting via the existing Suspense-contra mechanism (no GL change needed for that part) while waiting on the `JournalSource` fix specifically. **Not building the `OpeningImportBatch`/CSV-parsing/route layer in this pass** - scoping that separately once GL's reference shape (offered) is reviewed, since it's bigger than the single use case and may overlap with what POP/SOP will also need for AR/AP. | IM: `RecordOpeningStockUseCase` (new); GL: `RecordInventoryReceiptUseCase` (needs the same `JournalSource` generalization POP is also waiting on) |
| Purchase Order Processing - POP | 2026-10-01T03:00:00Z | Scoping only (per GL's heads-up), not building yet - Opening Figures CSV Upload step 4 (AR/AP, docs/Opening_Figures_CSV_Upload_DDD_Design.md §4.3), POP's AP half: new `ImportOpeningApLineUseCase`, contra = Suspense, rejects unknown `supplier_code` rather than auto-creating. **BLOCKED on IM's step 3 (Stock) landing first** per the design doc's own sequencing, and on GL generalizing `RecordVendorObligationUseCase` to accept a caller-supplied `JournalSource` - confirmed directly that POP's own `GlEngineGateway.recordVendorObligation()` has no such parameter today, same hardcoded-source gap GL already fixed on `RecordOpeningBalanceUseCase`/`CreateFixedAssetUseCase`. Not starting real build until both land. | POP: new `ImportOpeningApLineUseCase`/route (TBD); GL: `RecordVendorObligationUseCase` (needs the same `JournalSource` generalization); IM: step 3 (Stock), no known POP dependency beyond "must land first" |

## Format for a new row

```
| <session name from ListAgents> | <ISO 8601 timestamp> | <one-line description> | <paths/repos, or "TBD"> |
```
