# FiSH Purchase Order Processing — Domain-Driven Design (design-only, no code yet)

**Status: design scoping, 2026-08-20. Nothing extracted, nothing deleted, nothing built.** This document is the next step after `docs/Ecosystem_Extraction_DDD_Design.md`, which scoped the general extraction question for Purchasing/Sales/Inventory together and resolved the Purchase-Order-specific split in its §1.1. That document deliberately deferred both destination and detailed shape ("design first, defer extraction"). The user then supplied a full Purchase Order Processing requirements/use-case document (`docs/UK/Purchase_Order_Processing_Requirements_Use_Cases.md`, UC-PO1–PO7/FR-PO01–08/NFR-PO01–05), scoped narrowly to Purchase Order Processing alone — Inventory Management and Sales Order Processing are referenced (UC-PO4 cross-references UC-IM2) but explicitly not duplicated or extended here. This document works out what that means concretely for the GL Engine and for the new system that will own Purchase Order Processing going forward.

This is the same treatment already given to Lending's `ArrearsCase` and HR/Payroll: a design pass before any code moves, following `[[feedback_park_dont_guess]]`.

---

## 0. Relationship to the GL Engine repo

Confirms and sharpens `docs/Ecosystem_Extraction_DDD_Design.md` §1.1's split, now grounded in the richer requirements doc rather than the general "interface through API only" instruction alone.

**Moves out of `fish-fish-gl-engine` entirely** — becomes the new Purchase Order Processing system's own aggregates, with real operational detail the GL Engine was never the right place for:
- `domain.purchasing.Creditor` / `CreditorId` (supplier running balance — redundant with the Ledger now that `AccountsPayableAging` derives entirely from posted `JournalLine` tags, confirmed by `docs/Ecosystem_Extraction_DDD_Design.md` §0's code inventory)
- `domain.purchasing.PurchaseOrder` / `PurchaseOrderLine` / `PurchaseOrderStatus` / `PurchaseOrderId` (goods/service line modeling, the Draft→Sent state machine — now superseded by the requirements doc's much richer lifecycle, §3 below)
- `application.PostPurchaseOrderUseCase`
- `infrastructure.persistence.ExposedPurchaseOrderRepository`, `ExposedCreditorRepository`, and the `purchasing_tables.kt` schema
- `infrastructure.web.PurchaseOrderRoutes.kt` and its `POST /purchase-orders/{id}/post` endpoint

**Stays in the GL Engine, unchanged:**
- `AccountsPayableAging` — already has zero dependency on `Creditor`/`PurchaseOrder` (§0 of the Ecosystem doc's own finding). No code change at all.

**Stays in the GL Engine, as new thin posting interfaces (replacing `PostPurchaseOrderUseCase`'s PO-aggregate-coupled shape):** two new application-layer use cases, mirroring the pattern already proven by `PostPayRunUseCase`/`RemeasureLeaveAccrualUseCase` — the calling system computes the number and supplies a vendor identifier as a plain tag value, no `Creditor` aggregate validates or stores it:

| Use case (name TBD) | Posts | Called when |
|---|---|---|
| *Record vendor obligation* | Dr caller-specified Expense/Asset account(s), Cr AP Control account, tagged `DimensionType.VENDOR` with a caller-supplied vendor identifier | UC-PO5, on successful three-way match (see §4 — **this is later than today's `PurchaseOrder.send()`**, a real behavior change, not a naming change) |
| *Record vendor payment* | Dr AP Control, Cr caller-specified settlement account (Cash, or a facility/financing-liability account per UC-PO6's role logic) | UC-PO6, on confirmed supplier payment |

The second use case is the thin version of `Creditor.makePayment()`, which today has no application-layer caller at all (confirmed by grep during this pass) — it exists only as a domain method exercised by tests. This extraction finally gives it one, just not inside this repo.

**Not part of this system's GL crossing at all:** Goods Receipt (UC-PO4). It's a shared event with Inventory Management (UC-IM2), which is a separate, not-yet-extracted context (`docs/Ecosystem_Extraction_DDD_Design.md` §1.3, still unresolved). Purchase Order Processing's own responsibility at UC-PO4 is only to move its own PO status from "open" to "received" once it learns receipt happened — not to call any GL Engine endpoint for the receipt itself. Today that's `PostInventoryReceiptUseCase`, called by whatever system currently owns receipt (still the GL Engine, until Inventory Management's own extraction is resolved).

---

## 1. Ubiquitous Language

| Term | Meaning |
|---|---|
| **Supplier** | Party from whom goods are purchased. Master data: name, payment terms, bank/aval arrangement (UC-PO1) — never crosses into the GL Engine except as an opaque vendor identifier tag on a `JournalLine`, the same treatment `Employee` gets on `LeaveAccrual`. |
| **Purchase Order (PO)** | An order to a Supplier: lines, delivery terms, facility/deal reference, and Prodeo's Deal Role (below). Owns its own richer lifecycle (§3) — this system's aggregate, not the GL Engine's. |
| **Prodeo Deal Role** | One of three values a PO must record: **Introducer/Arranger**, **Co-Equity Provider**, or **Full Financier** (FR-PO02). Directly determines which account UC-PO6's payment posting credits (§4) — the single most consequential field this document adds relative to the GL Engine's current, role-blind `PurchaseOrder.send()`. |
| **Three-Way Match** | UC-PO5's control: PO, Goods Receipt, and Supplier Invoice must agree within a configurable tolerance before an AP liability is confirmed in FiSH. Owned entirely by this system — the GL Engine never sees "match," only the confirmed result (the *Record vendor obligation* call, §0). |
| **GRN / Invoice Received Clearing** | A holding account for goods received but not yet invoice-matched (UC-IM2's "credit Accounts Payable (or GRN/Invoice Received clearing account, pending UC-PO5 invoice matching)"). Not a new GL Engine concept — just an `AccountId` the calling system points a receipt or obligation posting at, same as any other caller-supplied account. See §5 for the timing question this raises. |
| **Facility** | A financing arrangement (e.g. a 90-day revolving trade facility) a PO may be drawn against. Tracked entirely in this system (NFR-PO05's utilisation reporting); the GL Engine has no `Facility` concept and doesn't need one for PO postings to work — the facility/financing-liability account UC-PO6 credits is just another caller-supplied `AccountId`. |
| **Approval Threshold** | UC-PO3's configurable value above which a PO requires CFO/Accountant sign-off before transmission to the Supplier — an operational workflow control internal to this system, not a GL Engine concern. |

---

## 2. Scope of this design pass

**Purchase Order Processing only**, matching the requirements doc's own explicit framing ("Goods Receipt... is referenced, not duplicated, here"). This deliberately does **not** re-open Inventory Management or Sales Order Processing — both remain governed by `docs/Ecosystem_Extraction_DDD_Design.md`'s own open questions (§1.2's ECL question, §1.3's Option A/B costing-engine fork), untouched by this document. Where this document needs to cross-reference receipt, it does so exactly as the requirements doc does: pointing at UC-IM2 without redesigning it.

---

## 3. Aggregates (new Purchase Order Processing system)

### 3.1 `Supplier`
- `id`, `name`, `entityId` (which Group entity trades with this Supplier — NFR-PO04), `facilityId?` (where relevant), `paymentTerms`, `bankAvalArrangement` (UC-PO1's SWIFT/aval detail — free-form or structured, not yet specified).

### 3.2 `PurchaseOrder`
- `id`, `supplierId`, `entityId`, `facilityId?`, `prodeoRole: DealRole` (mandatory, UC-PO2/FR-PO02), `lines: List<PurchaseOrderLine>`, `deliveryTerms` (e.g. "CIF Conakry").
- **Status lifecycle**, richer than the GL Engine's current `Draft→Sent`: `Draft → PendingApproval → Approved → Sent → PartiallyReceived → FullyReceived → Matched → Closed`, with `Cancelled` and `Amended` as side-transitions per UC-PO7. Exact transition rules (which states require CFO approval, which are reversible) not finalized in this pass — flagged, not guessed, since the requirements doc itself doesn't fully specify every edge (e.g. can a `Sent` PO return to `Draft`?).
- `send()`'s current responsibility (recognizing AP immediately) **no longer belongs here** — see §4, AP recognition moves to UC-PO5.

### 3.3 `PurchaseOrderLine`
- `description`, `item`, `quantity`, `price`, `itemType` (goods/service, same distinction the GL Engine's `LineItemType` already draws) — no `accountId` needed on this system's side, since account routing now happens at the *Record vendor obligation* call (§0), not per-line inside this aggregate.

### 3.4 `InvoiceMatch`
- `purchaseOrderId`, `invoiceReference`, `goodsReceiptReference` (UC-PO4/UC-IM2's event), `result: Matched | Mismatched`, `varianceDetail?` (when mismatched, UC-PO5.2's "flagged for Procurement Admin resolution"). Tolerance itself (§5, open) is configuration, not a field on each match.

### 3.5 `SupplierPayment`
- `purchaseOrderId` (or `invoiceMatchId`), `amount`, `executingParty` (Bank vs. Prodeo directly, UC-PO6.1), `bankConfirmationReference?` (when the Bank executes payment on the structure's behalf, this system records the Bank's instruction/confirmation rather than initiating payment itself, UC-PO6.1). Drives which GL Engine account the *Record vendor payment* call credits (§0/§4).

---

## 4. GL Engine crossing points — sequencing, and the one real behavior change

**A genuine finding, not guessed:** applying the requirements doc's UC-PO4/UC-PO5/UC-PO6 sequence to the GL Engine's existing capability surfaces that **AP recognition moves later than it happens today.** Currently, `PurchaseOrder.send()` recognizes the full AP liability the moment a PO is sent ("when we order we owe," `docs/DDD_Design.md` §2.5). The new requirements doc's UC-IM2/UC-PO5 sequence instead:

1. **Goods Receipt (UC-IM2, Inventory Management's own posting, unaffected by this document):** Dr Inventory, Cr Accounts Payable **or** a GRN/Invoice Received clearing account, pending match.
2. **Three-Way Match (UC-PO5, this system):** on success, FiSH "clears the GRN/Invoice Received clearing account... and posts the confirmed Accounts Payable liability" — i.e. the *Record vendor obligation* call (§0) fires here, not at PO-send.
3. **Payment (UC-PO6, this system):** the *Record vendor payment* call, role-driven account selection.

This means PO-send (UC-PO2/UC-PO3) itself **never calls the GL Engine at all** — it's pure operational workflow (creation, approval) inside the new system, with no financial effect until goods are actually received and matched. This is a materially different, and arguably more correct, IFRS position than what's built today (recognizing a liability before the goods have even arrived overstates AP relative to what's actually owed) — but it is a real, consequential change from the currently-built and tested Increment 1 behavior, not a reformulation of it. **Flagged for explicit confirmation before extraction begins**, not assumed.

**On `docs/Ecosystem_Extraction_DDD_Design.md` §2's atomicity question:** that document asked whether Purchasing/Inventory splitting into separate systems forces the orchestrating system to accept eventual consistency between an AP posting and an inventory posting, since they used to be one atomic `JournalEntry`. Applying this requirements doc's actual sequencing **resolves that question for Purchase Order Processing specifically**: receipt (Inventory's call) and AP recognition (this system's call, at match) were never meant to be the same GL Engine call in the first place — they're already separated by the three-way match step in between. No new combined endpoint is needed on the GL Engine side for Purchasing; the two calls are naturally sequential, not a single atomic operation split awkwardly in two.

---

## 5. Open questions

**Carried forward from `docs/UK/Purchase_Order_Processing_Requirements_Use_Cases.md`'s own "open decisions," genuinely unresolved, not guessed here either:**
1. Prodeo's actual role on the sugar deal (introducer/arranger vs co-equity 15% vs full financier) — the system supports recording any of the three; which one applies is a business decision pending the next Access Bank conversation.
2. PO approval threshold (UC-PO3) — no figure set.
3. Three-way match tolerance (UC-PO5) — no percentage set.
4. Facility utilisation calculation rule (NFR-PO05) — depends on final facility terms with the Bank.

**Surfaced newly by this design pass:**
5. **AP recognition timing change (§4)** — moving recognition from PO-send to three-way-match is a real behavior change from what's currently built and tested in `fish-fish-gl-engine`. Needs explicit confirmation, not just an implied acceptance by virtue of building the new system this way.
6. **GRN/Invoice Received clearing account — new `Account` classification or just any caller-chosen account?** No new GL Engine abstraction is strictly required (§1's ubiquitous-language entry treats it as a plain `AccountId`), but worth confirming that's sufficient rather than needing a dedicated `AccountClassification` value, given the existing classification scheme already distinguishes control accounts.
7. **Extraction destination — still not decided.** `docs/Ecosystem_Extraction_DDD_Design.md` §4 left this open across all three contexts. Nothing in this document or the requirements doc resolves it for Purchase Order Processing specifically: new standalone system (own repo, own tech stack), folded into a broader "Order Management" system alongside a future Sales Order Processing extraction, or something else.
8. **Repo/tech stack** for the new system — untouched, same gap `docs/HR_Payroll_DDD_Design.md` §7 item 5 flagged for HR/Payroll and never resolved there either.
9. **Vendor identifier shape crossing the boundary** — raw `String`/`UUID`, or a minimal non-authoritative `VendorId` value type kept purely for `DimensionType.VENDOR` tagging type-safety (the same treatment `EmployeeId` gets on `LeaveAccrual` even though `Employee` itself lives entirely outside the GL Engine)? Smaller question, doesn't block further design.
10. **PO status transition rules** (§3.2) — not fully specified; which transitions require CFO approval beyond UC-PO3's initial threshold and UC-PO7's partial-receipt amendment case isn't fully enumerated in the source requirements doc.

None of these block further design work — they block moving from design to code, the same discipline `docs/Ecosystem_Extraction_DDD_Design.md` and every prior sibling-system design pass already followed.

---

## 6. What this document changes right now

**Nothing in `fish-fish-gl-engine`.** `Creditor`/`PurchaseOrder`/`PurchaseOrderLine` and their use case/repository/route stay exactly as built. This document exists so that when extraction actually happens, item 5 (the AP-timing change) in particular gets confirmed deliberately rather than discovered mid-build, and so the two new thin use cases (§0) have an agreed shape before anyone writes them.
