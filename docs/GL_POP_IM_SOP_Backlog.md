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
| 0.1 | Merge + deploy POP's per-Company auth fix (`PopMembershipAuthorizer`, commit `22b8743`) | POP | — | Committed, not pushed/deployed — holding for user go-ahead |
| 0.2 | Merge + deploy IM's per-Company auth fix (`ImMembershipAuthorizer`, [PR #6](https://github.com/prodeo-group-dev/fish-inventory-management/pull/6)) | IM | — | PR open, not merged/deployed — holding for user go-ahead |
| 0.3 | Confirm whether SOP has the same per-Company auth bug as POP/IM, and fix if so | SOP | — | **Not yet confirmed either way** — a branch `fix/sop-per-company-write-scoping` already exists on SOP (pushed to origin) but has zero commits on it, meaning someone suspected this before today's joint audit but never actually checked or fixed it. Flagged by the GL session 2026-09-28 after independently verifying GL's own side is clean (see the "not yet waved" table below) — SOP is the one of the four still genuinely open. |

These are independent of each other (different services, different repos)
but share one root cause and one open user decision (whether/when to
deploy) — listed together so that decision gets made once, not twice.

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
