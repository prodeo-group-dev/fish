# VAT — the RoI MVP Threshold

**Status**: design/requirements only, 2026-09-13 — updated same day with all five open questions worked through to real decisions (on instruction). Nothing built yet. Direct instruction: Tax (Sales/VAT) is the capability that actually crosses the MVP threshold for FiSH, scoped to **one jurisdiction** — Republic of Ireland, continuing this project's RoI-anchor strategy (`docs/IE/IE_MVP_Definition.md`). This document supersedes that doc's earlier framing of VAT as a deferred, gated item — it's now the headline build, not step 3.

## Why this is a real build, not a small addition

Confirmed directly against current code (2026-09-13), not assumed:

- `TaxType` has exactly one member, `CORPORATE_INCOME_TAX`. Its own KDoc already names the reason VAT was excluded: it needs "a genuinely different, two-sided computation (output tax on sales minus input tax on purchases)... a way to tag which specific *transactions* are VAT-eligible - a real new modeling concern this codebase doesn't have yet."
- `ComputeTaxUseCase` computes off a Period's posted `JournalEntry`s via `ProfitAndLoss.of()` — a period-end profit figure. VAT isn't a profit-based tax; it's due on the *gross value* of individual sales and purchases, independent of whether the company made a profit that period. This is a different computation shape, not a parameter on the existing one.
- **No VAT field exists anywhere in SOP's sales lines or POP's purchase lines** (checked directly, not inferred) — there's no per-line tax rate or tax amount to compute from yet.
- **No VAT control account exists in the Chart of Accounts template** — `companyLimitedAccounts()` has Accounts Receivable, Accounts Payable, Sales Revenue, Operating Expenses, and payroll/facility accounts, but nothing VAT-shaped.

## The actual Irish VAT rates (already researched, `docs/IE/IE_Tax_And_Currency_Settings.md`)

Five bands — genuinely more than the UK's three, so any rate-lookup structure built for this needs to hold an arbitrary number of bands, not assume three or five as a fixed count:

| Rate | Value | Applies to |
|---|---|---|
| Standard | 23% | Default rate |
| Reduced | 13.5% | Building services, certain fuels, etc. |
| Second reduced | 9% | Food, catering, hairdressing — **changes 1 July 2026**, permanently cut from 13.5% |
| Super-reduced | 4.8% | Livestock only |
| Zero | 0% | Zero-rated goods/services |

The 1 July 2026 mid-year rate change is a real scheduling detail worth carrying into the design (whichever rate-effective-dating mechanism gets built needs to handle a rate changing mid-year, not just annually).

## What needs to be built

### 1. Domain modeling (GL) — a genuinely new shape, not an extension of `RateStructure`

`RateStructure`'s existing shapes (`Flat`, `Tiered`, `CategorySplit`, `ThresholdExemption`) were all built for **taxpayer-level** Corporate Income Tax — one rate resolved once per computation, against a taxpayer's total profit or its category. VAT needs a **line-level** rate lookup: each sale/purchase line carries its own VAT category (standard/reduced/second-reduced/super-reduced/zero), and the rate applied depends on *what's being sold*, not who the taxpayer is. This is closer to `CategorySplit`'s "rate depends on a caller-supplied category" idea in spirit, but at a different granularity (per-transaction-line vs. per-taxpayer) — **needs its own type, not a forced reuse of `CategorySplit`.**

Concretely: a `VatCategory` enum (standard/reduced/secondReduced/superReduced/zero) and a rate lookup keyed by it, plus a genuinely new `TaxType.VALUE_ADDED_TAX` member with its own computation path (output VAT collected minus input VAT paid, for a filing period) — not routed through `TaxComputation.of()`'s existing profit-based logic.

### 2. SOP (Sales) — output VAT

Each `SalesOrderLine` needs a VAT category and computed VAT amount. `RecordOrdinarySaleUseCase`/`RecordSaleUseCase` need to post the VAT portion to a new VAT control account in the Ledger, alongside the existing Sales Revenue/Accounts Receivable postings — this is a real Ledger-posting change (a third leg on what's currently a two-account entry), not just a reporting-layer addition.

### 3. POP (Purchases) — input VAT

Same shape, mirrored: each `PurchaseOrderLine` needs a VAT category and computed amount, and the receipt/three-way-match postings need to include the input VAT leg against the same (or a paired) control account.

### 4. Chart of Accounts — new control account

**Decided (§ Decisions below): a single netting "VAT Control Account."**

### 5. VAT return computation — the actual MVP deliverable

A new use case (mirroring `ComputeTaxUseCase`'s existing shape, but with genuinely different inputs) that sums a filing period's output VAT postings minus input VAT postings and produces the net amount due/reclaimable. This is the concrete thing that "crosses the MVP threshold" — a real, correct VAT liability figure for an RoI Company, computed from real recorded sales and purchases.

### 6. Filing — deliberately out of this MVP's threshold, in follow-on scope

`docs/External_Regulatory_And_Banking_API_Integrations_Requirements_Specification.md`'s UC-EXT04 (Revenue ROS VAT3 filing) is the natural next step once the computation above is real and correct — but filing a number is a smaller, separate problem from computing it correctly, and was already scoped in that spec. Recommend treating "compute the right VAT liability" as the MVP bar, and ROS filing as the immediate fast-follow, not bundled into the same threshold.

## Decisions (worked through 2026-09-13, on instruction — no longer open)

### 1. VAT category lives on the transaction line, not on IM's `Item` master

Checked directly before deciding, not assumed: **`SalesOrderLine` has no `itemId` field at all** — it's a plain `description`/`quantity`/`unitPrice` line with zero link to IM's Item master today (its own KDoc confirms "`itemType`/facility fields are left for a later increment"). `PurchaseOrderLine` does have an `itemId`, but it's nullable and explicitly documented as often absent ("a lot of pre-existing test/production data has none").

Given that, sourcing VAT category from `Item` would require adding item-linkage to `SalesOrderLine` as a *prerequisite* to VAT — a bigger, separate change — and would still fail for the POP lines that genuinely have no `itemId`. **Decision: `SalesOrderLine`/`PurchaseOrderLine` each get their own `vatCategory: VatCategory` field, supplied by the caller at line-creation time.** This is not just simpler; it's the only option that actually works against the data shape that exists today. An `Item`-level default category is a legitimate later UX convenience (auto-suggest a category when building a line against a known Item) — but the line must always store what actually applied, since that's an immutable historical fact independent of whatever the Item's current default is.

### 2. A single netting "VAT Control Account," not separate Payable/Receivable

A VAT-registered small business's real net position swings between owing VAT (output > input) and being owed a refund (input > output) — often period to period. A strict separate-Payable(liability)/Receivable(asset) split would require reclassifying the account's own nature depending on which way the period nets out, which is exactly the kind of complexity this codebase's own minimal-builds discipline argues against building on day one. **Decision: one liability-classified "VAT Control Account,"** credited by output VAT, debited by input VAT — its balance directly *is* the return figure (a credit balance is what's owed; a debit balance is a reclaim), with no separate netting step needed at return-computation time. Splitting into two accounts for presentation purposes is a reporting-layer choice that can be added later without a Ledger-structure change.

### 3. Bi-monthly filing cadence for MVP

Ireland's default VAT period is bi-monthly (VAT3, six periods/year); quarterly/4-monthly/6-monthly/annual exist for smaller traders by application. **Decision: build for bi-monthly only.** A VAT filing period is modeled as a plain two-calendar-month date range — the same shape generalizes to other cadences later (a filing-period length becomes a configuration value, not a structural change) once a real trader actually needs one.

### 4. VAT computation is the MVP bar; ROS filing (UC-EXT04) is the immediate fast-follow, not bundled in

Matches the precedent `ComputeTaxUseCase` itself already set for Corporate Income Tax — a correct computation, persisted and reportable, "does not post back into the Ledger... in v1," and that was already accepted as sufficient to be real, useful software. **Decision: the same bar applies to VAT** — a correct, real VAT Control Account balance for an RoI Company, derived from actual recorded sales and purchases, is what crosses the MVP threshold. ROS filing is the next thing built, directly motivated by having a real number to file, but its absence doesn't mean VAT computation isn't "done."

### 5. Minimal effective-dating, built now — not deferred

`TaxRule`'s own KDoc already flags "no effective-dating/rate-history modeling" as a known limitation for Corporate Income Tax, deferred "until tax-rate history actually needs representing." For VAT specifically, that need is not hypothetical — the second-reduced rate is already legislated to change from 13.5% to 9% on 1 July 2026, a date inside the normal horizon of this build. Deferring the mechanism would mean shipping something already known to go stale. **Decision: the VAT rate lookup takes an `asOf: LocalDate` (the transaction's own date) and each `VatCategory`'s rate table entry carries an `effectiveFrom: LocalDate`,** resolving to the most recent entry not after `asOf`. This is deliberately minimal — not a general rate-history system, just enough to get the one already-known change right without a second build pass in mid-2026.

## Relationship to the existing RoI MVP definition

This document reprioritizes `docs/IE/IE_MVP_Definition.md`'s Dimension 1 (Platform MVP): VAT moves from "confirmed gap, out of scope for MVP" to **the** threshold capability, ahead of SOP/POP/IM/HR/EA's wider feature set. Dimension 2 (External Integrations MVP) is unaffected in its own sequencing except that UC-EXT04 (ROS filing) now has a real, motivated reason to follow directly once VAT computation lands, rather than being the last item on a longer list.

## Implementation status (2026-09-20) — built and tested, GL + SOP + POP

The full computation-and-posting slice above (everything except §6 ROS filing) is now built end to end, following the approved plan at the session's own plan file. TDD throughout, `gradle test` green in all three repos.

**One domain correction made during the build, not in the design above**: `VatCategory` ended up with **six** values, not five — the original five-value list ("zero") conflated two legally distinct concepts. `ZERO_RATED` (0%, still within VAT scope — input VAT on related costs stays reclaimable) and `EXEMPT` (outside VAT scope entirely — no output VAT, and input VAT on directly-attributable costs is *not* reclaimable) are genuinely different and needed separate values. `EXEMPT` has no rate-table entry at all — its VAT is always zero by construction, never by a 0%-rate lookup. **Deliberately deferred**: full partial-exemption input-VAT apportionment (the calculation a trader with *both* taxable and exempt outputs needs, to determine how much shared/overhead input VAT it can reclaim) — MVP assumes a fully-taxable trader for input-VAT-recovery purposes; revisit only if a real RoI Company with exempt supplies needs it.

**Atomicity, per the "required atomicity is high" instruction**: GL resolves the rate (`asOf` the transaction date, against `VatRateSchedule.IRELAND` — correctly resolving the 1 Jul 2026 `SECOND_REDUCED` change) and computes the amount inside the same call that posts the `JournalEntry`. `RecordSaleUseCase.Request`/`RecordVendorObligationUseCase.Request` both moved from a single lump `amount: Money` to `lines: List<...>` (`netAmount` + `vatCategory`), a genuine breaking change to both thin posting interfaces, propagated in lockstep through SOP's and POP's own `RecordSaleUseCase`/`RecordThreeWayMatchUseCase` and their `gl_engine_dtos.kt` wire shapes.

**Audit trail**: each VAT leg is tagged with a new `DimensionType.VAT_CATEGORY` (not `CUSTOM_1` — open item #4 above resolved in favor of a real enum value), so the VAT Control Account's balance is explainable category-by-category from posted `JournalEntry` data, the same way `AccountsReceivableAging`/`AccountsPayableAging` already derive their reports — not an opaque running total.

**`VatReturn`/`VatFilingPeriod`**: built as designed — a plain date-range `VatFilingPeriod` independent of GL's own accounting `Period`s, and a persisted, immutable-once-computed `VatReturn` (`ComputeVatReturnUseCase`, `POST /companies/{companyId}/vat-return`, gated by `ManagedModule.TAX`) exposing a signed net figure so a refund position (input > output) isn't misread as an error.

**Open item #1 resolved differently than either option originally posed**: `VatCategory` is **not** a shared `fish-common` type — each repo (GL, SOP, POP) defines its own copy, validated at the API boundary (a raw enum-name string over the wire, parsed with a 400 on an invalid value). This avoided the `fish-common` version-bump/republish question entirely rather than answering it.

**Payment/refund settlement (design doc §, the plan's own Step 7)** — no new GL code needed, confirming the plan's prediction: once a `VatReturn` is filed, the actual cash movement reuses `CashBookEntry` unchanged, exactly like every other counter-account posting. Paying Revenue is `Dr VAT Control Account / Cr Cash` (`CashDirection.PAID`); receiving a refund is the reverse (`CashDirection.RECEIVED`). `CashBookEntry.counterAccountId` is a plain `AccountId`, not restricted to any particular account, so pointing it at the VAT Control Account created by this build needs zero new mechanism — same reasoning already used for wallet top-ups in the unrelated BuzzMe design pass.

**Honestly outstanding, not yet done:**
- **No verification against a real Postgres instance.** GL's `VatReturnRepository`/`V25__vat_returns.sql`, and POP's `vat_category` column persistence (`V9__purchase_order_line_vat_category.sql`) both have integration tests written, but `POP_DB_USER`/`POP_DB_PASSWORD` aren't set in this environment — `gradle integrationTest` ran and reported success, but every test in it was *skipped* (`assumeTrue` guard), not actually executed against a database. This is the same gap the plan's own verification checklist flagged in advance; nothing here has proven the schema/mapping actually works against real Postgres yet.
- ROS filing (UC-EXT04, §6 above) — still out of scope, unstarted, as designed.
- `VatCategory` enum ownership stays three separate copies (GL/SOP/POP) rather than a shared type — a deliberate scope-avoidance, not a considered rejection of the `fish-common` option; revisit if the duplication becomes a real maintenance cost.
