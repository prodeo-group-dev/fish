# FiSH GL Engine — Sales Processing Requirements Specification

**Version:** 1.0
**Author:** Copilot (for Femi)
**Standards Basis:** IFRS 15, IAS 2, IFRS 9, IAS 21, IAS 1, IFRS 13
**Scope:** Sales Order → Delivery → Revenue Recognition → COGS → Receivables → FX → Financial Statements

**Status: reference, 2026-08-21.** Broader in scope than `SOP/docs/Sales_Order_Processing_Requirements_Use_Cases.md` and `docs/Sales_Order_Processing_DDD_Design.md` — this describes general GL Engine sales-processing capability (full IFRS 15 5-step contract decomposition, multi-currency FX, formal ECL), of which SOP's trade-finance scenario (self-liquidating Bill for Collection, single-currency, aval-gated) is one specific case, not a replacement or supersession. Confirmed with the user directly. See `[[project_sales_processing_requirements_specification]]` for the gap analysis against what's actually built, and for which pieces of this spec are being built first (IAS 21 FX, since it's the one requirement with zero existing code or design to build on).

---

## 1. Purpose

Define the functional, accounting, and data requirements for the Sales Processing Module within the FiSH GL Engine, ensuring full compliance with IFRS and UK/Irish GAAP (FRS 102 Section 23 & 13).

## 2. Governing Standards

Sales processing must comply with:

**Primary Standard**
- IFRS 15 — Revenue from Contracts with Customers

**Supporting Standards**
- IAS 2 — Inventories (COGS, cost formulas, NRV)
- IFRS 9 — Financial Instruments (trade receivables, ECL)
- IAS 21 — FX Effects (multi-currency sales)
- IAS 1 — Presentation (FS classification & disclosures)
- IFRS 13 — Fair Value (non-cash consideration)

## 3. Functional Requirements

### 3.1 Contract & Sales Order Recognition (IFRS 15 Step 1)

The system must:
1. Validate contract existence (commercial substance, enforceable rights).
2. Support multiple contract types: spot sales, forward sales, CIF/FOB/EXW structured trade.
3. Capture contract attributes: customer identity, performance obligations, pricing terms, delivery terms, currency, credit terms.

Output: `ContractRecord` + `SalesOrder`

### 3.2 Performance Obligation Identification (IFRS 15 Step 2)

The system must:
- Identify distinct performance obligations (e.g., delivery of goods, warranties, services).
- Support composite obligations (e.g., bundled logistics + goods).
- Store obligation-level metadata.

Output: `PerformanceObligation[]`

### 3.3 Transaction Price Determination (IFRS 15 Step 3)

The system must:
- Calculate transaction price including base price, variable consideration (rebates, discounts, returns), non-cash consideration (IFRS 13 fair value).
- Apply constraints on variable consideration.

Output: `TransactionPrice`

### 3.4 Allocation of Transaction Price (IFRS 15 Step 4)

The system must:
- Allocate price to performance obligations using standalone selling price, observable inputs, or estimated fair value (IFRS 13).
- Support allocation adjustments.

Output: `PriceAllocation[]`

### 3.5 Revenue Recognition (IFRS 15 Step 5)

The system must:
- Determine whether revenue is recognised point-in-time (typical for goods) or over-time (if criteria met).
- Apply IFRS 15 control indicators: physical possession, legal title, risks and rewards, acceptance, ability to redirect use.

Output: `RevenueEvent`

## 4. Inventory & COGS Requirements (IAS 2)

### 4.1 Inventory Costing

The system must support IAS 2-compliant cost formulas: Weighted Average Cost (default for fungible commodities), FIFO, Specific Identification (for non-interchangeable items).

**Prohibited:** LIFO

### 4.2 Inventory Derecognition

Triggered when IFRS 15 control transfers. System must reduce inventory quantity, apply cost formula, generate COGS posting.

Output: `COGSEvent`

### 4.3 NRV Testing

The system must perform NRV tests at period end and at trigger events (market price drops, spoilage), distinguishing physical adjustments (quantity changes) from NRV write-downs (valuation changes).

Output: `NRVAdjustmentEvent`

## 5. Receivables Requirements (IFRS 9)

### 5.1 Trade Receivable Recognition

Upon revenue recognition, system must create receivable at transaction price, classified as amortised cost.

Output: `ReceivableRecord`

### 5.2 Expected Credit Loss (ECL)

System must apply the simplified approach for trade receivables, supporting lifetime ECL, a provision matrix, and forward-looking information.

Output: `ECLEntry`

### 5.3 Derecognition

System must derecognise receivable upon settlement and record FX differences (IAS 21).

## 6. FX Requirements (IAS 21)

System must:
- Translate foreign-currency sales at spot rate on transaction date.
- Revalue receivables at period-end rate.
- Recognise FX gains/losses in P&L.
- Support multi-currency ledgers.

Output: `FXRevaluationEvent`

## 7. GL Posting Requirements

### 7.1 Core Posting Flows

**Revenue Recognition**
- Dr Receivable
- Cr Revenue

**Inventory Derecognition**
- Dr COGS
- Cr Inventory

**NRV Write-Down**
- Dr Inventory Write-Down Expense
- Cr Inventory

**FX Revaluation**
- Dr/Cr FX Gain/Loss
- Cr/Dr Receivable

**Cash Settlement**
- Dr Cash
- Cr Receivable

## 8. Data Model Requirements

**Entities:**
`ContractRecord`, `SalesOrder`, `PerformanceObligation`, `TransactionPrice`, `PriceAllocation`, `RevenueEvent`, `InventoryLot`, `COGSEvent`, `ReceivableRecord`, `ECLEntry`, `FXRate`, `FXRevaluationEvent`

**Attributes must include:** currency, FX rate source, cost formula, control transfer timestamp, customer credit terms, contract metadata.

## 9. Audit & Compliance Requirements

System must maintain a full audit trail of contract changes, price changes, revenue recognition events, inventory movements, FX revaluations, and ECL calculations. Must support IFRS disclosures, FRS 102 disclosures, and iXBRL tagging (IAS 1 driven).

## 10. Non-Functional Requirements

**Performance** — Must process high-volume commodity trades efficiently.

**Accuracy** — Must guarantee IFRS-compliant postings.

**Traceability** — Every GL entry must be traceable to: contract, delivery, revenue event, inventory lot, FX rate.

**Extensibility** — Must support future modules: trade finance, derivatives, multi-entity consolidation.
