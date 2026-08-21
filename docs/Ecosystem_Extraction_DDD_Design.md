# FiSH Ecosystem Extraction — Purchase Order Processing, Sales Order Processing, Inventory Management (design-only, no code yet)

**Status: design scoping, 2026-08-20, updated 2026-08-21. Nothing extracted, nothing deleted.** The user asked directly: "We need to abstract the Sales Order Processing, Inventory management and Purchase Order Processing away from the FiSH GL Engine such that they interface through API only." Confirmed via `AskUserQuestion` the same day: **design first, defer extraction** — the same treatment already given to Lending's `ArrearsCase` (`docs/DDD_Design.md` Section 2.3, "confirmed to need relocation out of the GL Engine repo, deferred") and the precedent `PayRun` already set for Payroll (`Payslip`/`PayrollDeductionLine`/`EmployerCostLine` were actually deleted and replaced by a thin company-level posting once HR/Payroll was confirmed separate — Section 10.17). This document is the design pass; the actual extraction is a distinct, future build. **Section 1.3's Option A/B fork (Inventory's costing engine) is now resolved — Option B, 2026-08-21. See Section 1.3 for the decision and its reasoning.**

This closes the loop on `[[project_ledger_scope_boundary]]`: "GL's sole purpose is financial effect, never operational detail; applies to every future module." Purchasing, Sales, and Inventory are the three remaining "ecosystem" increments (of four) still living inside `fish-fish-gl-engine` with real operational domain logic, not just a thin posting interface — Payroll is the only one of the four that's already gone through this transition.

---

## 0. What's actually in the GL Engine repo today

Confirmed by direct code inventory, 2026-08-20 (not guessed):

| Context | Aggregates with operational state | Ledger-derived reports (no aggregate dependency) | Use cases | HTTP routes |
|---|---|---|---|---|
| Purchase Order Processing | `Creditor` (balance), `PurchaseOrder`/`PurchaseOrderLine` (goods/service lines, Draft→Sent) | `AccountsPayableAging` | `PostPurchaseOrderUseCase` | `POST /purchase-orders/{id}/post` |
| Sales Order Processing | `Customer` (balance, ECL allowance), `SalesOrder`/`SalesOrderLine` (delivery lines, Draft→PartiallyDelivered→Fulfilled) | `AccountsReceivableAging` | `PostSalesOrderUseCase` | **none** — never opened over HTTP |
| Inventory Management | `StockItem` (quantity, unit cost, WIP stage, NRV write-down), `OverheadAllocation` (pure calculation) | — | `PostInventoryReceiptUseCase`, `PostInventoryIssueUseCase` | `POST /stock-items/{id}/receipts`, `POST /stock-items/{id}/issues` |

**A genuinely good finding, not something to guess around:** `AccountsPayableAging.of()`/`AccountsReceivableAging.of()` already derive entirely from posted `JournalLine`s tagged with `DimensionType.VENDOR`/`DimensionType.CUSTOMER` — they never read `Creditor`/`Customer` state directly. Both reports already have zero dependency on the aggregates this document is scoping the removal of. **Whatever else this extraction does, the aging reports need no code change at all.**

**The real coupling problem, confirmed by grep, not assumed:** `PurchaseOrder.send()` calls `stockItem.recordReceipt()` directly, in-process, for GOODS lines; `SalesOrder.deliverLine()` calls `stockItem.recordIssue()` and reads `stockItem.unitCost` to compute COGS, also in-process. Once Purchasing/Sales/Inventory are three separate systems (or even just two, if Inventory stays), this call can no longer happen inside one JVM call stack — see §2.

---

## 1. What moves out vs. what stays — per context

### 1.1 Purchase Order Processing

**Moves out:** `Creditor` (supplier master data, running balance — redundant with the Ledger now that aging derives from `JournalLine` tags alone), `PurchaseOrder`/`PurchaseOrderLine` (goods/service line modeling, quantity, the Draft→Sent state machine). This becomes the separate system's own aggregate, with its own supplier master data, PO approval workflow, receiving workflow, etc. — real operational detail the GL Engine was never the right place for.

**Stays in the GL Engine, as a thin posting interface (name and exact shape not yet designed — see §3):** the separate system computes the AP amount and calls a GL Engine use case that posts Dr Expense/Asset, Cr Accounts Payable Control, tagged `DimensionType.VENDOR` with a caller-supplied vendor identifier — no `Creditor` aggregate validates or stores that identifier anymore, it's just a tag value on the `JournalLine`, exactly like `PayRun` carries no `Employee` reference. `Creditor.makePayment()` (Dr AP, Cr Cash) becomes an equally thin "post this vendor payment" call.

**Stays unchanged:** `AccountsPayableAging` (§0).

### 1.2 Sales Order Processing

**Moves out:** `Customer` (name, running balance), `SalesOrder`/`SalesOrderLine` (delivery-line modeling, the Draft→PartiallyDelivered→Fulfilled state machine).

**Stays in the GL Engine, as a thin posting interface:** the separate system computes the revenue amount (and COGS amount, if the line is GOODS) and calls a GL Engine use case that posts Dr AR Control/Cr Revenue (and Dr COGS/Cr Inventory if applicable), tagged `DimensionType.CUSTOMER` with a caller-supplied identifier.

**Stays unchanged:** `AccountsReceivableAging` (§0).

**Genuinely open, not guessed (§4.1):** `Customer.assessExpectedCreditLoss()` — IFRS 9 Expected Credit Loss, bad-debt provisioning that directly changes the Balance Sheet's net receivable figure and the P&L's bad-debt expense line. This reads and writes an `allowanceForExpectedCreditLoss` field currently living on `Customer`. Does ECL assessment move out with `Customer`, or does it get re-homed as a GL-Engine-native `Provision`-style aggregate (the same pattern `Provision`/`AccruedExpense`/`Borrowing` already use — company-level financial provisions with no operational aggregate behind them)? The precedent for the latter already exists in this codebase; the precedent for the former is "everything about `Customer` leaves." Not decided.

### 1.3 Inventory Management — the hardest one, flagged as the single most consequential open question in this document

Unlike Purchasing/Sales, `StockItem` has **no genuinely operational content at all today** — no location, no physical count, no reorder point, no barcode, nothing a warehouse system would actually need. Every field it has (`quantityOnHand`, `unitCost`, `stage`, `nrvWriteDownPerUnit`) exists purely to answer one question: *what is this inventory worth on the Balance Sheet, and what should flow to COGS?* That's IAS 2 (`docs/DDD_Design.md`'s own manufacturing-grounding notes: IAS 2 backbone + IFRS 15), not operational inventory management. `OverheadAllocation` is the same — a pure IAS 2.13 calculation, not a warehouse concept.

This is structurally different from Purchasing/Sales, where the moving-out aggregates (`Creditor`/`Customer`/`PurchaseOrder`/`SalesOrder`) are unambiguously operational and the GL Engine's replacement is unambiguously thin. For Inventory, it's not obvious the "thin GL interface" and "the whole aggregate" are different things at all — **parked, not guessed:**

- **Option A — the whole costing engine (`StockItem`'s quantity/cost/WIP/NRV state, `OverheadAllocation`) stays in the GL Engine**, since it's arguably indistinguishable from Ledger valuation (the same reasoning that already keeps `FixedAsset`'s depreciation/impairment logic in this repo rather than treating it as "Asset Management operational detail"). A new, separate Inventory Management system would then own only genuinely physical/operational concerns this codebase has never modeled — location, physical stock counts, reorder points — and would call the GL Engine's API (already built: `PostInventoryReceiptUseCase`/`PostInventoryIssueUseCase`) to record the *financial* effect of a physical movement it tracks operationally on its own side.
- **Option B — `StockItem`'s state moves out entirely**, and the GL Engine is reduced to accepting caller-supplied, already-computed amounts with no persisted inventory-valuation state of its own at all (closer to how `PostInventoryReceiptUseCase`/`PostInventoryIssueUseCase` already build their `JournalEntry` directly rather than via a `StockItem` domain method — though today they still read/write `StockItem`'s persisted quantity/cost through the repository, which Option B would remove). Under this option, WIP/NRV/overhead allocation entirely relocate to the separate system, and the Balance Sheet's Inventory figure would need to be pushed *into* the GL Engine as a caller-supplied valuation rather than computed by it.

The user's own phrasing grouped all three contexts together as one requirement ("interface through API only"), which reads as leaning toward Option B — but Option A has real IFRS-grounding weight the other two contexts don't share, and picking wrong here is expensive to unwind. **Not resolved in this document.**

**Resolved 2026-08-21 — Option B.** User's explicit reasoning: *"Costing should be in IM. The GL should be for committed costs. While Option A may seem easier, Option B is where the heavy lift should be done. We should not conflate business rules and accounting for money spent properly."* This draws the boundary on a different axis than the one this document originally reasoned from — not "is this IFRS-grounded valuation logic" (which favored Option A, via the `FixedAsset` analogy) but "is this a business rule (how do we cost/value inventory) versus an accounting fact (money actually committed/spent)." Costing/valuation is a business rule set — how weighted-average blends, when WIP accumulates cost, what NRV write-down applies — and belongs in `IM/`, the system that owns that operational judgment. The GL Engine's job is narrower than "compute the right value": it's to record the *committed cost* `IM/` hands it, immutably, once. This is a stricter, more literal reading of `[[feedback_loose_coupling_high_cohesion]]`'s "sibling systems get FiSH's narrowest interface" than Option A gave it credit for — the `FixedAsset` precedent doesn't get revisited by this decision (depreciation/impairment weren't in scope here), but it's no longer being treated as binding precedent for Inventory specifically.

**A second, independent justification, added after the resolution surfaced a genuine build-vs-decision conflict (see IM's own commit history) and worth recording alongside the first:** the name settles it. An "Inventory Manager" that manages inventory has to include *valuing* what it manages, not just moving quantities around while deferring to another system to say what any of it is worth — Option A would have made `IM/` a manager of everything about inventory except the one question "what is this worth," which doesn't hold together as a coherent system boundary regardless of the IFRS-grounding argument that motivated it. This is a plainer, more obvious angle than the business-rule/accounting-fact framing above, and arguably should have been the first thing checked before Option A's `FixedAsset` analogy was given as much weight as it was.

**Concrete implications:**
- ~~`StockItem` (quantity, unit cost, `InventoryStage`, `nrvWriteDownPerUnit`), `OverheadAllocation`, and all IAS 2 costing logic (weighted-average blend, WIP `consumeInto`/`addProductionCost`/`completeInto`, `assessNetRealisableValue`) move to `IM/` in full — not partially. GL Engine keeps none of this state after migration.~~ **Done, 2026-08-21** — ported onto `IM/`'s `Item` aggregate (previously master-data-only), plus `InventoryStage`/`OverheadAllocation`, 95 tests. `GL/`'s own `StockItem`/`OverheadAllocation` are unchanged and still present (see below - this was additive in IM, not yet subtractive in GL).
- ~~`PostInventoryReceiptUseCase`/`PostInventoryIssueUseCase` in GL Engine need to change shape...~~ **Resolved differently than originally described, 2026-08-21** — rather than changing the existing use cases' shape, two new thin posting interfaces were added *alongside* them: `RecordInventoryReceiptUseCase`/`RecordInventoryIssueUseCase` (mirroring `RecordSaleUseCase`/`RecordVendorObligationUseCase`'s already-established "Record" pattern for SOP/POP exactly - `companyId` carried directly in the request since there's no aggregate to derive tenant scoping from, `DimensionType.ITEM` added as the new tag dimension). This matches the precedent those two use cases themselves set ("`domain.sales.Customer`/`SalesOrder` still exist here unchanged... this use case is additive, coexisting with the old `PostSalesOrderUseCase`") rather than the original framing here, which assumed the old use cases would be rewritten in place. `PostInventoryReceiptUseCase`/`PostInventoryIssueUseCase` are untouched and still exist, still `StockItem`-driven - correct, since `PurchaseOrder.send()`/`SalesOrder.deliverLine()` (next bullet) still depend on `StockItem` compiling and existing. 563 GL tests pass.
- `PurchaseOrder.send()`/`SalesOrder.deliverLine()`'s in-process calls into `StockItem` (§2's coupling problem) are **still unresolved** - both still call `StockItem.recordReceipt()`/`recordIssue()`/read `unitCost` directly, now a confirmed architectural inconsistency (the only remaining GL-Engine-internal paths still doing IAS 2 decision-making the user's own framing says shouldn't happen here) rather than a hypothetical one. §2's atomicity question (eventual consistency across two API calls vs. a new combined endpoint) is still load-bearing and still needs an answer before these two methods can be changed to call `IM/` instead.
- `StockItem`/`OverheadAllocation` themselves are still fully present and unchanged in `GL/` - not yet deleted, not yet even deprecated. They remain load-bearing for `PurchaseOrder`/`SalesOrder` until the previous bullet resolves; deleting them now would break compilation, not just violate the Option B boundary.

---

## 2. The coupling problem, concretely (§0's grep finding)

`PurchaseOrder.send()` and `SalesOrder.deliverLine()` currently produce **one atomic `JournalEntry`** covering both the AP/revenue effect and the inventory effect, inside a single in-process call. Once Purchasing/Sales are separate systems from Inventory (whichever way §1.3 resolves), that single atomic operation becomes **at least two separate API calls** from whatever system orchestrates order fulfillment — one to post the AP/revenue entry, one to post the inventory receipt/issue.

This is a real consistency question the extraction has to answer, not an implementation detail to sort out later: does the orchestrating system accept eventual consistency between "AP posted" and "inventory received" (two independent GL Engine calls, no shared transaction), or does the GL Engine need a new combined endpoint that accepts both effects atomically in one request? **Parked** — worth resolving before extraction begins, since it changes the shape of the replacement interface in §1.1/§1.2, not after.

---

## 3. Interface shape — draft direction, not final

The precedent already fully established in this codebase (`AccruedExpense`, `Borrowing`, `PayRun`, and now the HR/Payroll and Inventory Management HTTP routes built 2026-08-26) is: **the calling system computes the number, the GL Engine only ever posts it and tags it.** No new architectural pattern is needed here — the thin replacement interfaces for Purchasing/Sales (§1.1/§1.2) are a straightforward application of a pattern this repo already uses four times over. What's undecided is naming and exact field shape (e.g. is the vendor/customer identifier a raw `String`, a `UUID`, or does the GL Engine keep a minimal, non-authoritative `VendorId`/`CustomerId` value type purely for dimension-tagging type-safety, the way `EmployeeId` survives on `LeaveAccrual` even though `Employee` itself lives entirely in HR/Payroll) — a smaller design question for whenever extraction actually starts, not blocking this pass.

---

## 4. Extraction destination — not decided

Lending's `ArrearsCase` has a confirmed destination (the Purse Credit Union Banking System's risk management module, `[[project_lending_separation]]`). HR/Payroll has a confirmed destination (its own new system, design-scoped in `docs/HR_Payroll_DDD_Design.md`). **Purchasing/Sales/Inventory have no confirmed destination yet.** Candidates, none decided:

- A new standalone system, mirroring HR/Payroll's shape (cross-venture, since Purse, Scrip, Osusu, and any B2B GL Engine tenant would all plausibly need purchasing/sales/inventory).
- Folded into Purse Core Banking, the way Lending was — plausible for Purse's own agrifinance/credit-union operations, less obviously right for a generic B2B SaaS tenant using the GL Engine standalone.
- Three separate systems rather than one combined "Order Management" system — Purchasing and Sales are natural siblings (mirror images of each other), but Inventory's fate (§1.3) may decouple it from both regardless of destination.

---

## 5. What this document changes right now

**Nothing in `fish-fish-gl-engine`.** `Creditor`/`PurchaseOrder`/`Customer`/`SalesOrder`/`StockItem` and their use cases/routes stay exactly as built. This document exists so that when extraction actually happens, the real open questions (§1.2's ECL question, §1.3's Option A/B fork, §2's atomicity question, §4's destination) get resolved deliberately rather than guessed mid-build — the same discipline `[[feedback_park_dont_guess]]` already established as this project's working style.
