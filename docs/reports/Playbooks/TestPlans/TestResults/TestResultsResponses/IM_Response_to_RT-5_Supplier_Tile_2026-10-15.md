# IM response to RT-5 (Inventory tile GBP 44,284.52 against trial balance 1300 GBP 44,285.00)

From the IM session, 2026-10-17. Also answers `POP_Test_Results_2026-10-13.md` flag "stock vs GL" (same figures) and CM's triage finding 1. Read from IM's code and the tester's own numbers; nothing was run against production.

## Verdict: rounding, not a mis-posting. A real flaw in IM's costing, small today and growing with quantity. Needs Femi's decision.

| Finding | Status | Detail |
|---|---|---|
| 0.48 between the Inventory tile (44,284.52) and TB 1300 (44,285.00) | **Not a mis-posting. A rounding flaw in IM's weighted-average cost. Needs a decision (recommendation below).** | The ledger is right; IM's valuation is the figure that is off. |
| The 5.00 receipt posted 1300 Dr 5.00 / 2000 Cr 5.00 | **Not a defect** | The posting is exact: GL records the cost received (5.00). 1300 went from 44,280.00 to 44,285.00, which is the true cost of the stock. |
| Where the 44,284.52 comes from | **Explained** | EA's tile sums IM's `totalValue` per stock item (`ComputeDashboardUseCase`, `toInventorySummary`). IM computes `totalValue` as `weightedAverageUnitCost x quantityOnHand` (`Item.totalValue`). |

## The arithmetic

- Before the receipt: 108 units at 410.00 = 44,280.00. Equal to GL 1300 exactly, because 410.00 needs no rounding.
- Receipt: 1 unit at 5.00. True average = (44,280.00 + 5.00) / 109 = **406.2844037**.
- IM holds the unit cost as `Money`, and `Money` rounds every value to the currency's minor unit (2 decimals for GBP, banker's rounding). The 4-decimal database column (`weighted_average_unit_cost_amount NUMERIC(19,4)`) never gets the extra digits. So the stored average is **406.28**.
- IM's value of the stock is then 109 x 406.28 = **44,284.52**. GL holds the exact **44,285.00**. Difference **0.48 = 109 x 0.0044037**.

## Why this matters beyond 0.48

1. **It does not correct itself.** The error is `quantity x (true average - rounded average)`, at most `quantity x 0.005`. The ceiling grows with the stock: about 5.00 for 1,000 units, 500.00 for 100,000 units, 5,000 for a million. A small shop will not feel it; a grain or fuel trader will.
2. **It reaches the cost of sales.** An issue costs `quantity x rounded average`. Issuing 10 units now posts COGS of 4,062.80 where the true average cost is 4,062.84. GL 1300 then falls by the posted cost, so the 0.48 difference between the ledger and IM's valuation stays in step with the stock. When the last unit is sold, 1300 still holds the stranded rounding residue, with no stock behind it.
3. **IM and GL can never be reconciled to the penny** while this stands, which is exactly what an accountant checks first (stock records against the control account). It also affects any "stock valuation report" vs "balance sheet" comparison.

## Options (recommendation first)

| Option | What changes | Cost |
|---|---|---|
| **A. Hold the total value, derive the unit cost (recommended)** | IM stores the stock's total value (to the penny) beside the quantity. A receipt adds the cost received. An issue costs `total value x quantity issued / quantity on hand`, rounded to the penny, and the last unit takes whatever remains. The displayed unit cost is derived. Stock value then equals the sum of what GL was told, by construction: no drift, no rounding residue, and the stock is exactly zero when the quantity is zero. | About 1.5 days in IM (domain, one additive migration, backfill, tests, a Postgres migration test). No change to GL, POP, SOP or any response field. |
| B. Keep a unit cost but at higher precision (e.g. 6 decimals) | The unit cost stays a figure but is no longer rounded to pennies. Shrinks the error by about 10,000 times; does not remove it. | About 0.5 day. Still has a residue at large quantities. |
| C. Do nothing, document it | Tell users the tile may differ from the ledger by a few pence. | None. Not recommended: the ceiling grows with quantity and the residue is stranded in 1300. |

## What the existing test data does

The live 0.48 is on legacy test data (everything in production is test data until the Live switch). With option A the stored total value is backfilled from the current figures (quantity x stored unit cost), which would fix the going-forward behaviour but keep today's 0.48 until the next full sell-through or a one-off adjustment journal. I suggest leaving the test data as it is; nothing real depends on it.

## Needs a decision

**Femi (as accountant):** option A, B or C. Per the 2026-10-16 principle ("the onus on us is to ensure we calculate it as accurately as possible"), I recommend A, and I have not started it. It is queued behind slice B of the VAT category unless Femi moves it up. It touches IM's costing core only, so it also needs CM's review at HIGH (a money calculation, no auth change).

## Not in scope here

The Inventory tile's other points (the clipped "item" text at 300% zoom) belong to WEB and were already superseded by RT-6's exact-viewport result (CM triage).
