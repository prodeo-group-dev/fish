# SOP — Returns Inwards: System Requirements Specification

**Status: build started, 2026-08-21.** Full RMA lifecycle for customer returns against Sales Orders/Invoices — initiation, approval, warehouse receipt/inspection, credit note/AR adjustment, inventory/GL postings, reporting. Scoped explicitly to **Returns Inwards** (goods returned *to* the Group by customers) — Returns Outwards (goods the Group returns to its own suppliers) is `POP`'s concern, named as a related future need but not built here.

Confirmed directly: this overrides the "pause further Sales Processing feature-building, go live first for 6 months" decision recorded the same day in `[[project_sales_processing_requirements_specification]]` — returns is treated as a near-term need worth building ahead of that window, not a violation of it.

---

## 1. System overview

The Returns Inwards module manages the full lifecycle of customer returns against sales orders/invoices. It ensures:
- Correct identification of items being returned
- Controlled authorization and logistics of return
- Accurate inventory and financial adjustments
- Integration with SOP, Inventory, Accounts Receivable, and Credit Notes
- Full auditability and compliance with revenue and inventory standards

## 2. Stakeholders

- **Customer Service / Sales Ops** — initiate and manage returns
- **Warehouse / Stores** — receive and inspect returned goods
- **Finance / Accounts Receivable** — process credit notes and AR adjustments
- **Sales Managers** — approve returns, monitor customer impact
- **Quality / Compliance** — analyze reasons and trends
- **Auditors** — verify traceability and postings

## 3. Functional requirements

### 3.1 Return initiation
- **FR‑RI1**: Link return to original sale — select source (Sales Order, Delivery Note, or Invoice); system shows items, quantities sold, quantities already returned, and remaining eligible quantity.
- **FR‑RI2**: Capture return details — return quantity per line; reason codes (Damaged, Defective, Wrong Item, Customer Cancellation, Late Delivery, Other); optional notes and photo evidence.
- **FR‑RI3**: Validate return eligibility — return window (configurable days from delivery/invoice); quantity does not exceed delivered quantity minus previous returns; customer's return terms (contractual rules, restocking fees, etc.).

### 3.2 Return authorization
- **FR‑RA1**: Approval workflow — configurable Customer Service → Sales Manager → Finance (if needed); approvers approve/reject/request more information; status Draft → Submitted → Approved → Rejected.
- **FR‑RA2**: Customer communication — generate RMA document with RMA number; send to customer via email/portal; include packaging/shipping/deadline instructions.

### 3.3 Physical return and inspection
- **FR‑PR1**: Goods receipt against RMA — warehouse records arrival, scans/matches RMA, records actual quantities received.
- **FR‑PR2**: Quality inspection — inspect condition/damage/completeness; classify Resaleable/Repairable/Scrap/Dispute; record results and photos.
- **FR‑PR3**: Inventory handling — Resaleable → saleable stock; Repairable → quarantine/repair location; Scrap → scrap location + write-off.

### 3.4 Credit note and AR integration
- **FR‑CN1**: Credit note creation — linked to original invoice and return document; calculate credit (full/partial/net of restocking fees); support discounts/taxes/FX.
- **FR‑CN2**: AR adjustment — reduce customer AR balance; update statement and aging report.

### 3.5 Inventory and GL adjustments
- **FR‑IF1**: Inventory adjustment — increase inventory for resaleable items at appropriate cost; separate movements for scrap/write-off.
- **FR‑IF2**: GL posting patterns:
  - Resaleable returns: Dr Inventory / Cr Sales Returns (contra revenue) or Cr Cost of Sales adjustment
  - Scrap/write-off: Dr Inventory Write-off Expense / Cr Inventory
  - Credit note: Dr Sales Returns (contra revenue) / Cr Accounts Receivable
- **FR‑IF3**: Audit trail — log all changes: user, timestamp, old/new values, approvals, postings.

### 3.6 Reporting and analytics
- **FR‑RE1**: Returns analysis — by customer, product, region, reason; value/volume over time.
- **FR‑RE2**: Exception/risk reports — high return rate customers/products; returns without inspection outcome; returns without credit note or with delayed credit issuance.

## 4. Non-functional requirements

- **Security**: Role-based access, segregation of duties (Sales/Finance/Warehouse), full audit logs
- **Performance**: Return creation and RMA generation < 2 seconds under normal load
- **Scalability**: Thousands of returns per month across multiple branches
- **Compliance**: IFRS 15, IAS 2
- **Availability**: 99.9% uptime for SOP and returns modules
- **Usability**: Simple guided workflows for customer service/warehouse staff; mobile-friendly receiving screens

## 5. Use case catalogue

- **UC‑01**: Initiate sales return (Customer Service/Sales Ops)
- **UC‑02**: Approve return request / RMA issuance (Sales Manager, optionally Finance)
- **UC‑03**: Receive returned goods (Warehouse Operative)
- **UC‑04**: Inspect returned goods (Warehouse/Quality Inspector)
- **UC‑05**: Issue credit note (Finance/AR)
- **UC‑06**: Post inventory and GL adjustments (System, Finance oversight)
- **UC‑07**: Analyze returns (Sales Manager/Quality/Finance)

(Full flows/exceptions for each use case are as originally specified; omitted here for brevity — see conversation history for the complete text if needed.)

## 6. High-level data model

Sales Order/Invoice, Return Request (Sales Return Header), Return Line, RMA (Return Authorization), Customer, Inventory Item/SKU, Inspection Result, Credit Note, AR Transaction, Inventory Transaction, GL Posting, Audit Log.

---

## 7. Build status against this spec

| Area | Status |
|---|---|
| **`ReturnRequest`/`ReturnRequestLine`/`ReturnReasonCode`/`ReturnRequestStatus`** (UC‑01/UC‑02, FR‑RI1‑3, FR‑RA1) | **Built**, `SOP/domain/returns`. `ReturnRequestLine` structurally enforces FR‑RI3 (quantity ≤ eligible, request date ≤ deadline) against caller-supplied facts — this aggregate has no visibility into prior returns or return-window policy to derive those itself. `ReturnRequest` owns `Draft→Submitted→Approved/Rejected` (FR‑RA1); "request more information" isn't a fifth status, handled via reject-with-reason + resubmission. |
| **Warehouse receipt/inspection/disposition** (UC‑03/UC‑04, FR‑PR1/PR2) | **Built** (2026‑09‑04), `SOP/domain/returns`. `ReturnRequestStatus` extended `Approved→Received→Inspected→Credited`, one-way and linear. New `Disposition` enum (Resaleable/Repairable/Scrap/Dispute) and `ReturnLineDisposition` value object; `ReturnRequest.receive()`/`.inspect(results)` validate each disposition's line index and quantity against the original request. **FR‑PR3's actual inventory handling (Resaleable→saleable stock, Repairable→quarantine, Scrap→write‑off) is still not built** — that's IM's concern and stays a distinct, not-yet-started crossing (deliberately out of scope for this pass, see below). |
| RMA document generation, customer communication (FR‑RA2) | Not built |
| **Credit note, AR adjustment** (UC‑05/06, FR‑CN1/2) | **Built** (2026‑09‑04). New `CreditNote` aggregate (`SOP/domain/returns`) — `Draft→Issued`, amount is caller-supplied per FR‑CN1's own "calculate credit (full/partial/net of restocking fees)" (this aggregate doesn't derive it). `IssueCreditNoteUseCase` requires the `ReturnRequest` be `Inspected`, then posts to GL — only saves/transitions on a successful post, so a GL failure leaves both aggregates safely retryable from `Inspected`. |
| **Inventory/GL postings — AR/credit-note side** (FR‑IF2, the "Dr Sales Returns / Cr Accounts Receivable" line) | **Built** (2026‑09‑04). New `RecordSalesReturnUseCase` in `GL/` (`POST /sales/record-sales-return`), the third thin posting interface alongside `RecordSaleUseCase`/`RecordCollectionUseCase` — mirror image of `RecordSaleUseCase`'s Dr AR/Cr Revenue. |
| **Inventory/GL postings — inventory-value side** (FR‑IF1/2, "Dr Inventory / Cr Sales Returns or Cost of Sales adjustment") | **Not built.** This is the one part of UC‑06 still open: crediting stock back in for a Resaleable disposition needs a new IM-side endpoint (mirroring how SOP's existing `ImGateway.recordGoodsIssue` calls `POST /items/{id}/issue`) — IM's existing `POST /items/{id}/receive` is PO-specific (requires a `purchaseOrderReference`, posts Dr Inventory/Cr AP, not the Returns-Inwards Dr Inventory/Cr Sales-Returns pattern) and isn't reusable as-is. Deliberately deferred rather than reaching into `IM` while it had unrelated concurrent work in flight. |
| Audit trail (FR‑IF3) | Partially free — `JournalEntry`'s append-only/reversal-only nature already gives posting-level audit trail; a Return Request's own approval history isn't separately logged yet (only current state) |
| Reporting/analytics (FR‑RE1/2) | Not built |
| **Application/persistence/web layers** | **Built** (2026‑09‑04) for the full UC‑01–06 lifecycle — previously domain-only with no way to reach `ReturnRequest`/`CreditNote` through the API at all. `SOP/application`: one use case per lifecycle step (`CreateReturnRequestUseCase`/`SubmitReturnRequestUseCase`/`ApproveReturnRequestUseCase`/`RejectReturnRequestUseCase`/`ReceiveReturnedGoodsUseCase`/`InspectReturnedGoodsUseCase`/`IssueCreditNoteUseCase`), matching this codebase's established one-class-per-use-case convention. `SOP/infrastructure/persistence`: `V4__returns_inwards.sql`, `ExposedReturnRequestRepository`/`ExposedCreditNoteRepository` (delete-then-reinsert child tables, same shape as `ExposedSalesOrderRepository`). `SOP/infrastructure/web`: `ReturnRequestRoutes.kt` — `POST/GET /return-requests`, `/submit`, `/approve`, `/reject`, `/receive`, `/inspect`, `/issue-credit-note`. Verified with a real end-to-end HTTP test driving the full lifecycle (create→submit→approve→receive→inspect→issue-credit-note, real JSON, real JWT) alongside unit tests for every layer. |

**Next natural increment, not started:** the IM-side goods-receipt-against-return endpoint (the inventory-value half of UC‑06) — everything else in UC‑01 through UC‑06 is now built end to end. RMA document generation (FR‑RA2) and reporting/analytics (FR‑RE1/2) remain separately unbuilt and unscheduled.
