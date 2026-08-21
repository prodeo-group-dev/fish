# FiSH GL Engine — IFRS GL Posting Matrix (Purchases, Sales, Inventory)

**Status: reference only, captured 2026-08-21. Nothing in this document has been implemented yet** — no code in `GL/`, `POP/`, `SOP/`, or `IM/` currently follows this matrix. Stored per the user's explicit choice ("store as reference doc now") rather than treated as immediate build instructions, matching this project's established handling of large reference specs (`docs/Sales_Processing_Requirements_Specification.md` got the same treatment).

**Why this matters right now:** it was supplied directly in response to `docs/Ecosystem_Extraction_DDD_Design.md` §2's still-open atomicity question (does the orchestrating system accept eventual consistency across two separate GL Engine API calls once `PurchaseOrder.send()`/`SalesOrder.deliverLine()` can no longer call `StockItem` in-process, or does GL Engine need a combined endpoint). This matrix's Case 1.1/1.3 (invoice-received-goods-not-received vs. goods-received-before-invoice) suggests §2's framing may have been slightly off: the AP/liability posting and the Inventory posting were never meant to be one atomic event in most real scenarios — they're genuinely two separate postings at two separate times (Goods-in-Transit → later reclassified to Inventory, or Inventory → GRNI → later cleared to AP), except in the FOB Shipping Point case where control transfers at shipment. This reframes §2 from "how do we keep two systems consistent for one atomic fact" toward "which of several genuinely-sequential posting paths applies, based on the PO/deal's actual control-transfer terms" — worth resolving deliberately before touching `PurchaseOrder.send()`/`SalesOrder.deliverLine()`, not guessed.

**Standards referenced throughout:** IAS 2 (Inventories), IFRS 15 (Revenue from Contracts with Customers — control-transfer logic), IFRS 9 (Financial Instruments — AP/AR, ECL), IAS 21 (The Effects of Changes in Foreign Exchange Rates), IAS 1 (Presentation of Financial Statements), IFRS 13 (Fair Value Measurement).

---

## Part A — Purchases

### A.0 Control-transfer framing (why timing matters)

Under IFRS, if the supplier invoice arrives before the goods, inventory cannot be recognised yet — a liability and a *pre-inventory asset* are recognised instead, depending on the nature of the transaction. Three cases:

**Case 1 — Invoice received, goods not yet received (standard credit purchase).** Goods are not yet under the entity's control → no inventory.
- Dr Goods-in-Transit / Prepaid Inventory (an asset representing the enforceable right to receive goods)
- Cr Accounts Payable (liability recognised at invoice amount)
- Why: IAS 2 recognises inventory only when the entity controls the goods; IFRS 15's control logic (direct use, obtain benefits) says a right to receive goods isn't the goods themselves.
- Account name options (all IFRS-compliant depending on chart of accounts): Goods-in-Transit, Prepaid Inventory, Inventory Accrual Asset.

**Case 2 — No invoice, goods not yet received (purchase contract only).** No GL entry — no liability (no invoice), no asset (no control of goods); a contract alone does not create a recognisable asset or liability under IFRS.

**Case 3 — Goods shipped FOB Shipping Point (supplier ships, buyer controls during transit).** If trade terms transfer control before physical receipt:
- Dr Inventory
- Cr Accounts Payable
- Even though goods are not physically received, control has transferred, so inventory is recognised. Common in commodity trading (directly relevant to the Group's own trade finance scenarios).

**Summary table — goods not yet received:**

| Scenario | Debit | Credit | Standard |
|---|---|---|---|
| Invoice received, goods not received | Goods-in-Transit / Prepaid Inventory | Accounts Payable | IAS 2, IFRS 9 |
| No invoice, goods not received | — | — | IFRS 15, IAS 2 |
| Control transfers before receipt (FOB Shipping Point) | Inventory | Accounts Payable | IAS 2, IFRS 15 |
| Freight-in before goods received | Goods-in-Transit | Accounts Payable | IAS 2 |

**How FiSH GL Engine should implement this (per the source material, not yet built):**
1. **Control transfer logic** — FiSH must evaluate delivery terms (FOB, CIF, EXW), shipping documents, contract terms, and the risk transfer point to determine which case applies.
2. **Pre-inventory asset** — FiSH must support a `GoodsInTransitAsset`/`PrepaidInventoryAsset` concept.
3. **Automatic reclassification** — when goods are received: Dr Inventory, Cr Goods-in-Transit.

### A.1 Purchases — goods not received yet

**A.1.1 Invoice received, goods not received (standard case)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Supplier invoice received | Goods-in-Transit / Prepaid Inventory | Accounts Payable | IAS 2, IFRS 9 |

**A.1.2 No invoice, goods not received**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Contract signed | — | — | IFRS 15, IAS 2 |

**A.1.3 Control transfers before physical receipt (FOB Shipping Point)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Control transfers at shipment | Inventory | Accounts Payable | IAS 2, IFRS 15 |

### A.2 Purchases — goods received

**A.2.1 Goods received + invoice received (normal case)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Inventory received | Inventory | Accounts Payable | IAS 2, IFRS 9 |

**A.2.2 Goods received before invoice (GRNI accrual)** — Goods Received Not Invoiced (GRNI) is required.

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Goods received, no invoice | Inventory | GRNI (Accrued Liability) | IAS 2 |
| Invoice arrives later | GRNI | Accounts Payable | IFRS 9 |

### A.3 Goods-in-transit reclassification

**A.3.1 Goods arrive after being recognised as Goods-in-Transit**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Goods received | Inventory | Goods-in-Transit | IAS 2 |

### A.4 Freight & direct costs

**A.4.1 Freight-in (directly attributable)** — included in inventory cost.

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Freight invoice | Inventory | Accounts Payable | IAS 2 |

**A.4.2 Freight not attributable (e.g. outbound)** — expensed.

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Outbound freight | Freight Expense | Accounts Payable | IAS 1 |

### A.5 Discounts

**A.5.1 Trade discount (before invoice)** — already netted in inventory cost, no separate posting.

**A.5.2 Settlement discount (after invoice)** — if discount is taken:

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Payment with discount | Accounts Payable | Cash | IFRS 9 |
| | | Purchase Discount Income | IAS 1 |

### A.6 Returns to supplier

**A.6.1 Inventory returned before payment**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Return of goods | Accounts Payable | Inventory | IAS 2 |

**A.6.2 Inventory returned after payment**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Supplier refund | Cash | Inventory | IAS 2 |

### A.7 FX effects (IAS 21)

**A.7.1 Invoice recognition (spot rate)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Foreign-currency invoice | Inventory / Goods-in-Transit | Accounts Payable (translated at spot) | IAS 21 |

**A.7.2 Period-end revaluation**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| AP revaluation (loss) | FX Loss | Accounts Payable | IAS 21 |
| AP revaluation (gain) | Accounts Payable | FX Gain | IAS 21 |

**A.7.3 Settlement**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Payment | Accounts Payable | Cash | IFRS 9 |
| FX difference | FX Loss/Gain | Cash/AP | IAS 21 |

### A.8 NRV write-down (IAS 2)

| Event | Debit | Credit | Standard |
|---|---|---|---|
| NRV write-down | Inventory Write-Down Expense | Inventory | IAS 2 |

### A.9 Physical stock adjustments

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Shrinkage / loss | Inventory Loss Expense | Inventory | IAS 2 |
| Surplus | Inventory | Inventory Gain (Other Income) | IAS 1 |

### A.10 Complete purchase lifecycle — summary matrix

| Stage | Debit | Credit |
|---|---|---|
| Invoice before goods | Goods-in-Transit | Accounts Payable |
| Goods received before invoice | Inventory | GRNI |
| Invoice arrives | GRNI | Accounts Payable |
| Control transfers in transit | Inventory | Accounts Payable |
| Freight-in | Inventory | Accounts Payable |
| Payment | Accounts Payable | Cash |
| FX revaluation | FX Loss/Gain | Accounts Payable |
| Returns | Accounts Payable | Inventory |
| NRV write-down | Write-Down Expense | Inventory |

---

## Part B — Sales

### B.1 Revenue recognition (IFRS 15)

**B.1.1 Point-in-time revenue (typical goods sale)** — triggered when control transfers.

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Revenue recognition | Accounts Receivable | Revenue | IFRS 15, IFRS 9 |

**B.1.2 Over-time revenue (if criteria met)** — e.g. long-term service or manufacturing contracts.

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Over-time revenue | Contract Asset | Revenue | IFRS 15 |

**B.1.3 Contract liability (advance payment)** — customer pays before goods delivered.

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Advance payment received | Cash | Contract Liability (Deferred Revenue) | IFRS 15 |
| Revenue recognised later | Contract Liability | Revenue | IFRS 15 |

### B.2 COGS & inventory derecognition (IAS 2)

**B.2.1 Inventory derecognition at control transfer**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| COGS posting | Cost of Goods Sold | Inventory | IAS 2 |

**B.2.2 Specific identification (non-interchangeable goods)** — same posting, cost traced to a specific lot.

| Event | Debit | Credit | Standard |
|---|---|---|---|
| COGS (specific lot) | COGS | Inventory (Lot ID) | IAS 2 |

### B.3 Accounts receivable (IFRS 9)

**B.3.1 Receivable creation**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Customer billed | Accounts Receivable | Revenue | IFRS 9 |

**B.3.2 Cash receipt**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Payment received | Cash | Accounts Receivable | IFRS 9 |

**B.3.3 Expected Credit Loss (ECL)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| ECL provision | Impairment Expense (ECL) | Allowance for Doubtful Debts | IFRS 9 |

**B.3.4 Bad debt write-off**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Write-off | Allowance for Doubtful Debts | Accounts Receivable | IFRS 9 |

### B.4 Discounts, rebates, returns (IFRS 15)

**B.4.1 Sales discount (post-invoice)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Discount granted | Sales Discount Expense | Accounts Receivable | IFRS 15 |

**B.4.2 Sales rebate (variable consideration)** — recognised at contract inception.

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Rebate accrual | Revenue | Rebate Liability | IFRS 15 |

**B.4.3 Sales return (goods returned)**

Step 1 — reverse revenue:

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Reverse revenue | Sales Returns (Contra-Revenue) | Accounts Receivable / Cash | IFRS 15 |

Step 2 — restore inventory:

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Restore inventory | Inventory | COGS | IAS 2 |

### B.5 FX effects (IAS 21)

**B.5.1 Revenue recognised in foreign currency (spot rate)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| FX translation at sale | Accounts Receivable (spot rate) | Revenue | IAS 21 |

**B.5.2 Period-end revaluation of receivable**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| FX loss | FX Loss | Accounts Receivable | IAS 21 |
| FX gain | Accounts Receivable | FX Gain | IAS 21 |

**B.5.3 FX difference at settlement**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Settlement FX variance | FX Loss/Gain | Cash / Accounts Receivable | IAS 21 |

### B.6 Non-cash consideration (IFRS 13)

If customer pays with goods, crypto, or other non-cash assets:

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Non-cash consideration | Asset Received (fair value) | Revenue | IFRS 13, IFRS 15 |

### B.7 Principal vs agent (IFRS 15)

**B.7.1 Principal (full revenue)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Sale | Accounts Receivable | Revenue (gross) | IFRS 15 |

**B.7.2 Agent (net revenue)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Commission revenue | Accounts Receivable | Commission Revenue (net) | IFRS 15 |

### B.8 Complete sales lifecycle — summary matrix

| Stage | Debit | Credit |
|---|---|---|
| Revenue recognised | Accounts Receivable | Revenue |
| COGS | COGS | Inventory |
| Cash received | Cash | Accounts Receivable |
| FX revaluation | FX Loss/Gain | Accounts Receivable |
| Returns (revenue reversal) | Sales Returns | AR/Cash |
| Returns (inventory restored) | Inventory | COGS |
| Advance payment | Cash | Contract Liability |
| Revenue from advance | Contract Liability | Revenue |
| ECL provision | Impairment Expense | Allowance |
| Bad debt write-off | Allowance | Accounts Receivable |

---

## Part C — Inventory

### C.1 Inventory acquisition (IAS 2)

**C.1.1 Goods received + invoice received (normal case)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Inventory acquisition | Inventory | Accounts Payable | IAS 2, IFRS 9 |

**C.1.2 Goods received before invoice (GRNI accrual)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Goods received | Inventory | GRNI (Accrued Liability) | IAS 2 |
| Invoice arrives | GRNI | Accounts Payable | IFRS 9 |

**C.1.3 Invoice received before goods (pre-inventory asset)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Invoice received | Goods-in-Transit / Prepaid Inventory | Accounts Payable | IAS 2, IFRS 9 |
| Goods arrive | Inventory | Goods-in-Transit | IAS 2 |

**C.1.4 Control transfers before physical receipt (FOB Shipping Point)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Control transfers | Inventory | Accounts Payable | IAS 2, IFRS 15 |

### C.2 Inventory costing (IAS 2)

FiSH must support (per the source material — only weighted-average is built today, see "Status against what's built" below):

| Method | Event | Debit | Credit |
|---|---|---|---|
| Weighted Average Cost | Issue inventory | COGS | Inventory (WAC) |
| FIFO | Issue inventory | COGS | Inventory (FIFO layers) |
| Specific Identification | Issue inventory | COGS | Inventory (Lot ID) |

### C.3 Inventory movements

**C.3.1 Internal transfer (warehouse → warehouse)** — no financial impact unless cost changes.

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Transfer | Inventory (Destination) | Inventory (Source) | IAS 2 |

**C.3.2 Repack / reprocess (cost increases)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Additional processing cost | Inventory | Processing Expense / AP | IAS 2 |

**C.3.3 Repack / reprocess (cost decreases)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Cost reduction | Inventory Reduction Expense | Inventory | IAS 2 |

### C.4 Inventory adjustments

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Physical stock loss (shrinkage, damage) | Inventory Loss Expense | Inventory | IAS 2 |
| Physical stock gain (surplus) | Inventory | Inventory Gain (Other Income) | IAS 1 |

### C.5 NRV write-down (IAS 2)

**C.5.1 NRV write-down**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Write-down | Inventory Write-Down Expense | Inventory | IAS 2 |

**C.5.2 NRV reversal (if conditions improve)** — reversal capped at original write-down.

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Reversal | Inventory | Inventory Write-Down Reversal (Income) | IAS 2 |

### C.6 Inventory returns

**C.6.1 Return to supplier (before payment)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Return | Accounts Payable | Inventory | IAS 2 |

**C.6.2 Return to supplier (after payment)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Refund | Cash | Inventory | IAS 2 |

### C.7 FX effects (IAS 21)

**C.7.1 Inventory purchased in foreign currency (spot rate)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Inventory acquisition | Inventory | Accounts Payable (spot rate) | IAS 21 |

**C.7.2 Period-end revaluation of AP**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| FX loss | FX Loss | Accounts Payable | IAS 21 |
| FX gain | Accounts Payable | FX Gain | IAS 21 |

**C.7.3 Settlement FX difference**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Settlement variance | FX Loss/Gain | Cash / Accounts Payable | IAS 21 |

### C.8 Production & manufacturing (IAS 2)

**C.8.1 Raw materials issued to production**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Issue RM | WIP (Work-in-Progress) | Inventory (Raw Materials) | IAS 2 |

**C.8.2 Conversion costs added**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Labour/overheads | WIP | Payroll / Overhead Absorption | IAS 2 |

**C.8.3 Finished goods completed**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| FG completion | Inventory (Finished Goods) | WIP | IAS 2 |

### C.9 Disposal of inventory

**C.9.1 Write-off (obsolete inventory)**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Write-off | Inventory Write-Off Expense | Inventory | IAS 2 |

**C.9.2 Scrap sale**

| Event | Debit | Credit | Standard |
|---|---|---|---|
| Cash received | Cash | Scrap Income | IAS 1 |

### C.10 Complete inventory lifecycle — summary matrix

| Stage | Debit | Credit |
|---|---|---|
| Goods received | Inventory | AP / GRNI |
| Invoice before goods | Goods-in-Transit | AP |
| Goods arrive | Inventory | Goods-in-Transit |
| Inventory issue | COGS / WIP | Inventory |
| Freight-in | Inventory | AP |
| Physical loss | Loss Expense | Inventory |
| Physical gain | Inventory | Gain Income |
| NRV write-down | Write-Down Expense | Inventory |
| NRV reversal | Inventory | Write-Down Reversal |
| Return to supplier | AP / Cash | Inventory |
| FX revaluation | FX Loss/Gain | AP |
| Production | WIP / FG | Inventory / WIP |

---

## Status against what's actually built (checked, not assumed)

Reference only — no gap-closing work has started. A first pass, to save whoever picks this up next from re-deriving it:

- **Costing method (Part C.2):** only weighted-average exists, in `IM/`'s `Item` (post-Option B) and historically in `GL/`'s `StockItem`. FIFO/Specific Identification are unbuilt anywhere.
- **Goods-in-Transit / GRNI (A.1.1/A.1.3/A.2.2/C.1.2/C.1.3): closed, 2026-08-21.** Two findings, not one build: (1) the GL-Engine *posting mechanics* were already sufficient before any new code was written — `RecordVendorObligationUseCase`/`RecordInventoryReceiptUseCase` (built the same day, for the Option B migration) are fully generic "debit whatever account the caller names" interfaces, so every leg of every case in this matrix was already mechanically representable through them, just undocumented as such. (2) The genuine gap was the *decision* (which case applies to a given PO) and the *timing* (goods-received and invoice-received as two separate events) — neither existed anywhere. Closed by extending `GL/`'s legacy `PurchaseOrder` (the only live PO implementation, `POP/` still has zero code): a new `DeliveryTerms` enum (`CONTROL_TRANSFERS_AT_SHIPMENT`, the original/default `send()` behaviour, vs. `CONTROL_TRANSFERS_AT_RECEIPT`), two new terminal-reachable `PurchaseOrderStatus` values (`GOODS_RECEIVED_PENDING_INVOICE`, `RECEIVED`), and three new methods alongside the unchanged `send()`: `receiveGoods()` (invoice-first path's reclassification, A.3.1), `receiveGoodsBeforeInvoice()`/`matchInvoice()` (the GRNI path, C.1.2/A.2.2). Mixed GOODS+SERVICE orders handled without restriction. Full persistence (Flyway `V7__purchase_order_delivery_terms.sql`, Exposed table/repository) included. `PurchaseOrderTest.kt` (the pre-existing `CONTROL_TRANSFERS_AT_SHIPMENT` suite) passes unmodified, confirming zero behaviour change for every existing caller. **Extended the same day, from a follow-up GRNI reference (not in this document's original scope):** `matchInvoice()` gained `invoicedGoodsAmount`/`varianceAccountId` parameters — a real invoice rarely matches the GRNI accrual exactly, and the difference now posts as its own debit/credit line to a caller-named account (Inventory if cost-attributable, a Purchase Price Variance account if not — that judgement is deliberately left to the caller, this aggregate has no way to make it); both default to preserving the original exact-match behaviour when omitted. A new `returnGoodsBeforeInvoice()` method (Dr GRNI, Cr Inventory, reverses the `StockItem` receipt) handles goods sent back before any invoice arrives, transitioning back to `DRAFT` rather than a dedicated state — Case 2's own logic (no goods, no invoice, nothing recognisable) already describes exactly where such an order sits, and it lets a replacement shipment call `receiveGoodsBeforeInvoice()` again with no special casing. GRNI *ageing*/*reconciliation* reporting remain unbuilt (the natural model to reuse is `AccountsPayableAging`'s existing pure-`JournalLine`-derived shape).
- **In-transit tracking:** `IM/`'s `InTransitShipment`/`LocationState` (UC-IM7) already models physical custody (in-transit vs. on-hand) but has no GL posting behaviour wired to it yet — this matrix's Goods-in-Transit *asset* concept is the missing financial-posting counterpart to that physical-state tracking.
- **NRV write-down/reversal (A.8/C.5):** already built in `IM/`'s `Item.assessNetRealisableValue()` (ported from `GL/`'s `StockItem`), matching this matrix's C.5.1/C.5.2 exactly, reversal cap included.
- **Physical stock loss/gain (A.9/C.4):** the loss half is covered by `InventoryAdjustment` (`IM/`, UC-IM6) and `PostInventoryReceiptUseCase`/`PostInventoryIssueUseCase`'s scenario-agnostic design (`GL/`); the gain/surplus posting direction isn't distinguished from loss anywhere today.
- **FX effects (A.7/B.5/C.7):** confirmed zero existing FX code anywhere in the codebase (`docs/Sales_Processing_Requirements_Specification.md` already flagged IAS 21 as the chosen first FX build target, unbuilt).
- **ECL (B.3.3/B.3.4):** already built (`Customer.assessExpectedCreditLoss()` in `GL/`, matching this matrix's shape).
- **Contract asset/liability, revenue over time, non-cash consideration, principal-vs-agent (B.1.2/B.1.3/B.6/B.7):** unbuilt; `Sales_Processing_Requirements_Specification.md`'s full IFRS 15 5-step decomposition is the closest existing reference for these, itself not yet built either.
- **Production/manufacturing (C.8):** already built in `GL/`'s WIP cost-flow (`StockItem.consumeInto`/`addProductionCost`/`completeInto`, ported to `IM/`'s `Item`) — matches C.8.1-8.3 exactly.
