# FiSH Sales Order Processing — Domain-Driven Design (design-only, no code yet)

**Status: design scoping, 2026-08-20. Nothing extracted, nothing deleted, nothing built.** This document is the Sales Order Processing counterpart to `docs/Purchase_Order_Processing_DDD_Design.md`. That document was the follow-on to `docs/Ecosystem_Extraction_DDD_Design.md`, which scoped the general extraction question for Purchasing/Sales/Inventory together and resolved the Sales-Order-specific split in its §1.2. This document works out what that means concretely for the GL Engine and for the new `SOP` system, grounded in `SOP/docs/Sales_Order_Processing_Requirements_Use_Cases.md` (UC-SO1–SO7/FR-SO01–09/NFR-SO01–05) — a requirements document scoped narrowly to Sales Order Processing alone. Order Fulfilment (UC-SO4) references *Inventory Management* (UC-IM3) but doesn't duplicate or extend it here.

This is the same treatment already given to Lending's `ArrearsCase`, HR/Payroll, and Purchase Order Processing: a design pass before any code moves, following `[[feedback_park_dont_guess]]`.

---

## 0. Relationship to the GL Engine repo

Confirmed by direct code inventory (`GL/src/main/kotlin/com/theprodeogroup/fish/domain/sales/sales_order.kt`, `customer.kt`), same day. Sharpens `docs/Ecosystem_Extraction_DDD_Design.md` §1.2's split, now grounded in the requirements doc rather than the general "interface through API only" instruction alone.

**Moves out of `fish-fish-gl-engine` entirely** — becomes SOP's own aggregates, with real operational detail the GL Engine was never the right place for:
- `domain.sales.Customer` / `CustomerId` (name, running balance — redundant with the Ledger now that `AccountsReceivableAging` derives entirely from posted `JournalLine` tags, confirmed by `docs/Ecosystem_Extraction_DDD_Design.md` §0's code inventory)
- `domain.sales.SalesOrder` / `SalesOrderLine` / `SalesOrderStatus` / `SalesOrderId` (delivery-line modeling, the computed Draft→PartiallyDelivered→Fulfilled status — now superseded by the requirements doc's richer lifecycle, §3 below, which adds an aval-confirmation gate and Bill for Collection tracking neither of which exist today)
- `application.PostSalesOrderUseCase`
- `infrastructure.persistence.ExposedSalesOrderRepository`, `ExposedCustomerRepository`, and the sales persistence tables
- `infrastructure.web.SalesOrderRoutes.kt`

**Stays in the GL Engine, unchanged:**
- `AccountsReceivableAging` — already has zero dependency on `Customer`/`SalesOrder` (§0 of the Ecosystem doc's own finding). No code change at all.

**Stays in the GL Engine, as new thin posting interfaces (replacing `PostSalesOrderUseCase`'s SalesOrder-aggregate-coupled shape):** two new application-layer use cases, mirroring the pattern already proven by `PostPayRunUseCase`/`RemeasureLeaveAccrualUseCase`/the two new Purchase Order Processing use cases (`Purchase_Order_Processing_DDD_Design.md` §0) — the calling system computes the number and supplies a customer identifier as a plain tag value, no `Customer` aggregate validates or stores it:

| Use case (built as `RecordSaleUseCase`/`RecordCollectionUseCase`) | Posts | Called when |
|---|---|---|
| *Record sale* | Dr AR Control account, Cr caller-specified Revenue account **only** — tagged `DimensionType.CUSTOMER` with a caller-supplied customer identifier. **Revised, 2026-08-20 (§4/§5 item 5 resolution):** no longer bundles COGS/Inventory in the same compound entry the way today's `SalesOrder.deliverLine()` does. Once revenue recognition can fire at the CIF loading point — materially earlier than physical goods issue at destination — bundling stops making sense: COGS/Inventory derecognition stays entirely Inventory Management's own responsibility (UC-IM3, its already-built `PostInventoryIssueUseCase`, itself proof this doesn't need a driving SalesOrder), firing independently whenever physical issue actually happens. | UC-SO5, at the contractually correct revenue recognition point (§4/§5 item 2 — resolved to the CIF loading point for the sugar deal, pending final contract-wording confirmation; see `[[project_sales_order_processing_ifrs_grounding]]`) |
| *Record collection* | Dr caller-specified settlement account (Cash, or a facility/financing-liability account per the Bill for Collection's mechanics), Cr AR Control | UC-SO6, on confirmed collection (`BillForCollection.collect()`) |

The second use case is the thin version of `Customer.recordReceipt()`, which today (like `Creditor.makePayment()` before Purchase Order Processing's own extraction pass) has no application-layer caller wired through a Sales Order — `[[project_receivable_ecl]]` already flagged and fixed a version of this gap once; this extraction gives the corrected caller a permanent home outside the GL Engine.

**Not part of this system's GL crossing at all:** Goods Issue (UC-SO4). It's a shared event with Inventory Management (UC-IM3), a separate, not-yet-extracted-to-code context (`IM/docs/Inventory_Management_Requirements_Use_Cases.md`, itself unresolved per `docs/Ecosystem_Extraction_DDD_Design.md` §1.3). Sales Order Processing's own responsibility at UC-SO4 is only to move its own SalesOrder status once it learns issue happened, and — the one condition specific to this system — to refuse that transition at all unless UC-SO3's aval confirmation is already recorded, regardless of what Inventory Management's own stock availability shows (FR-SO03).

---

## 1. Ubiquitous Language

| Term | Meaning |
|---|---|
| **Customer/Buyer** | Party to whom goods are sold. Master data: name, credit terms, buyer-side aval/guarantee arrangement (UC-SO1) — never crosses into the GL Engine except as an opaque customer identifier tag on a `JournalLine`, the same treatment `VendorId`/`EmployeeId` get elsewhere. |
| **Sales Order (SO)** | An order to a Customer: lines, delivery terms, facility/deal reference, and aval status. Owns its own richer lifecycle (§3) — this system's aggregate, not the GL Engine's. |
| **Aval Confirmation** | UC-SO3's hard gate: explicit confirmation that the buyer-side aval (or equivalent credit enhancement) is in place. FR-SO03/NFR-SO01 make this a **default-blocking** control, not a soft warning — fulfilment cannot proceed without it, and any override requires a named CFO/Accountant-level authority (open question, §5). The single most consequential field this document adds relative to the GL Engine's current, aval-blind `SalesOrder.deliverLine()`. |
| **Bill for Collection (BfC)** | UC-SO6's tracked instrument: presented → accepted/avalised → due → collected. Replaces "post an invoice and wait" — a materially different, stateful collection mechanism this system owns entirely; the GL Engine never sees the BfC's own state, only the confirmed collection result (the *Record collection* call, §0). |
| **Facility** | A financing arrangement (e.g. a 90-day revolving trade facility) a Sales Order may be drawn against. Tracked entirely in this system (NFR-SO04's headroom reporting, FR-SO07's link to the next Purchase Order cycle); the GL Engine has no `Facility` concept and doesn't need one for SO postings to work. |
| **Revenue Recognition Point** | UC-SO5/FR-SO05's contractually-defined moment revenue is recognised — may not coincide with physical goods issue (e.g. CIF risk-transfer). A property of the Sales Order's contract terms, resolved once per term-type (NFR-SO05) and applied consistently, not decided ad hoc per transaction. |

---

## 2. Scope of this design pass

**Sales Order Processing only**, matching the requirements doc's own explicit framing ("Order Fulfilment... is referenced, not duplicated, here"). This deliberately does **not** re-open Inventory Management or Purchase Order Processing — both remain governed by their own documents (`IM/docs/...`, `docs/Purchase_Order_Processing_DDD_Design.md`). Where this document needs to cross-reference issue, it does so exactly as the requirements doc does: pointing at UC-IM3 without redesigning it.

---

## 3. Aggregates (new SOP system)

### 3.1 `Customer`
- `id`, `name`, `entityId` (which Group entity sells to this Customer — NFR-SO03), `facilityId?` (where relevant), `creditTerms`, `avalArrangement` (UC-SO1's aval/guarantee detail — free-form or structured, not yet specified, mirroring `Supplier.bankAvalArrangement`'s open shape in the PO design).

### 3.2 `SalesOrder`
- `id`, `customerId`, `entityId`, `facilityId?`, `lines: List<SalesOrderLine>`, `deliveryTerms`.
- **Status lifecycle**, richer than the GL Engine's current computed `Draft→PartiallyDelivered→Fulfilled`: `Draft → AvalConfirmed → PartiallyFulfilled → Fulfilled → Invoiced → PartiallyCollected → Collected`, with `Cancelled` and `Amended` as side-transitions per UC-SO7. `AvalConfirmed` is a hard prerequisite state — no transition into `PartiallyFulfilled`/`Fulfilled` is legal without passing through it first (FR-SO03). Exact transition rules not finalized in this pass, same discipline as the PO document's §3.2 — flagged, not guessed.
- `deliverLine()`'s current responsibility (recognizing AR/revenue immediately on delivery) is retained in spirit but gated: the equivalent call on this system's side must check `avalConfirmed` before proceeding, and the *timing* of the GL Engine crossing depends on the resolved revenue recognition point (§4), not necessarily the delivery moment itself.

### 3.3 `SalesOrderLine`
- `description`, `item`, `quantity`, `price`, `itemType` (goods/service, same distinction the GL Engine's `LineItemType` already draws) — no `accountId` needed on this system's side, since account routing now happens at the *Record sale* call (§0), not per-line inside this aggregate.

### 3.4 `AvalConfirmation`
- `salesOrderId`, `confirmedBy` (Sales Admin, CFO/Accountant, or Bank — UC-SO3's actor list), `confirmedAt`, `evidenceReference?` (documentary evidence of the aval, not yet specified). A record of *when and by whom* the gate was satisfied — NFR-SO02's traceability requirement needs this to be its own fact, not just a boolean flipped on `SalesOrder`.
- **Override path (NFR-SO01, open — §5):** if a CFO/Accountant-level override is ever exercised to bypass an unconfirmed aval, that override must be a separately logged fact distinct from a genuine confirmation — modeling both as the same `AvalConfirmation` shape with an `isOverride: Boolean` flag is one option, not yet decided.

### 3.5 `BillForCollection`
- `salesOrderId`, `presentedAt`, `status: Presented | Accepted | Due | Collected`, `avalisingBank?`, `dueDate?`, `collectedAmount?`. Drives which GL Engine account the *Record collection* call credits/debits (§0/§4) and, on `Collected`, may trigger `FacilityHeadroom` recalculation (§3.6).

### 3.6 `FacilityHeadroom` (or a calculated property of `Facility`, TBD)
- Tracks a revolving facility's available capacity, restored on confirmed collection (UC-SO6/FR-SO07) and consumed by the next cycle's Purchase Order (feeding Purchase Order Processing's own `PurchaseOrder.facilityId`, UC-PO2). Exact restoration rule (full amount, net of margin, timing lag) is the open item carried forward from the requirements doc — see §5.

---

## 4. GL Engine crossing points — sequencing, and the open questions it surfaces

**A genuine finding, not guessed:** applying the requirements doc's UC-SO3/UC-SO4/UC-SO5/UC-SO6 sequence to the GL Engine's existing capability surfaces two real questions, mirroring what the Purchase Order Processing design pass found on the AP side:

1. **Aval Confirmation (UC-SO3, this system, no GL Engine call):** pure operational gate-check, no financial effect.
2. **Goods Issue (UC-SO4, Inventory Management's own posting, unaffected by this document, gated by step 1):** COGS/Inventory effect, per `IM/docs/Inventory_Management_Requirements_Use_Cases.md`.
3. **Sales Invoice Generation (UC-SO5, this system):** the *Record sale* call (§0) fires here — **but at the contractually correct revenue recognition point, which the requirements doc explicitly says may not coincide with step 2** (FR-SO05, e.g. CIF risk-transfer timing). Today's `SalesOrder.deliverLine()` always fires at delivery; this is a real, consequential decoupling from currently-built and tested Increment 2 behavior, not a reformulation of it. **Resolved, 2026-08-20:** for CIF terms specifically, control/risk transfers at the port of loading (goods loaded on board the vessel) under both Incoterms and IFRS 15's control-transfer test — materially earlier than physical destination receipt. Treated as a strong candidate answer, not yet confirmed against the actual contract wording (`[[project_sales_order_processing_ifrs_grounding]]`).
4. **Collection (UC-SO6, this system):** the *Record collection* call (§0), Bill for Collection-state-driven rather than a simple "invoice paid" flag.

**On the Ecosystem doc's §2 atomicity question:** applying this requirements doc's actual sequencing resolves it for Sales Order Processing the same way the PO document resolved it for Purchasing — issue (Inventory's call) and revenue recognition (this system's call, at step 3) were never meant to be the same GL Engine call once the recognition point can diverge from the issue moment. No new combined endpoint is needed on the GL Engine side.

**On the Ecosystem doc's §1.2 ECL question — resolved, 2026-08-20:** does `Customer.assessExpectedCreditLoss()` (IFRS 9 Expected Credit Loss, currently reading/writing `allowanceForExpectedCreditLoss` on `Customer`) move out with `Customer` entirely, or get re-homed as a GL-Engine-native `Provision`-style aggregate (the precedent `Provision`/`AccruedExpense`/`Borrowing` already establish)? **ECL stays GL-Engine-native.** IFRS 9's ECL is fundamentally a *balance*-based measurement, and SOP's `Customer` (§3.1) was built with zero balance/receivable state by deliberate design — there's no balance in SOP to measure ECL against. See `[[project_sales_order_processing_ifrs_grounding]]` for the full reasoning.

---

## 5. Open questions

**Carried forward from `SOP/docs/Sales_Order_Processing_Requirements_Use_Cases.md`'s own "open decisions," genuinely unresolved, not guessed here either:**
1. Buyer-side aval confirmation status on the sugar deal itself (is the Guinean commercial bank's aval actually confirmed) — this document builds the control that will enforce it once confirmed; doesn't resolve the confirmation itself.
2. **Revenue recognition point (§4 step 3) — resolved with high confidence, pending final contract confirmation.** For CIF terms, control/risk transfers at the port of loading, per both Incoterms and IFRS 15's control-transfer test. This is the answer NFR-SO05 asks be applied consistently per contract-term type; still worth a final check against the actual signed contract wording before treating as fully locked in.
3. Aval-override governance (§3.4) — who specifically holds override authority if a genuine business case requires proceeding without confirmed aval.
4. Facility headroom mechanics (§3.6) — full amount, net of margin, or timing lag, pending the facility's actual terms with the Bank.

**Surfaced newly by this design pass:**
5. **Revenue-recognition timing decoupling (§4) — resolved.** Recognition moves from delivery-triggered to contract-term-triggered (item 2 above); confirmed as the correct IFRS 15 treatment, not just an implementation convenience. `RecordSaleUseCase`/`RecordCollectionUseCase` built accordingly (§0).
6. **`Customer.assessExpectedCreditLoss()` destination (§4) — resolved.** Stays GL-Engine-native, doesn't move to SOP. See §4's updated ECL paragraph.
7. **Extraction destination — still not decided.** Same open item as Purchase Order Processing (§5 item 7 there) and Inventory Management: new standalone system, folded into a broader "Order Management" system, or something else. `SOP` having its own repo now answers "where does the requirements doc live," not "where does the eventually-running system live."
8. **Customer identifier shape crossing the boundary** — raw `String`/`UUID`, or a minimal non-authoritative `CustomerId` value type kept purely for `DimensionType.CUSTOMER` tagging type-safety, mirroring the same open question Purchase Order Processing's design left for `VendorId` (§5 item 9 there). Smaller question, doesn't block further design.
9. **SalesOrder status transition rules (§3.2)** — not fully specified; which transitions require CFO approval beyond the aval gate and UC-SO7's post-fulfilment amendment case isn't fully enumerated in the source requirements doc.
10. **`AvalConfirmation`/override modeling (§3.4)** — whether an override is the same aggregate shape with a flag, or a distinct concept entirely, not decided.

Items 2/5/6 (revenue-recognition timing, ECL destination) are now resolved, which is what unblocked building `RecordSaleUseCase`/`RecordCollectionUseCase` (§0). The remaining items don't block further design work — they block moving from design to code only on the specific areas they touch. The rest of the model (§3.1–3.3, 3.5, 3.6's structure if not its exact restoration rule) is buildable now.

---

## 6. What this document changes right now

**Nothing in `fish-fish-gl-engine`.** `Customer`/`SalesOrder`/`SalesOrderLine` and their use case/repository/route stay exactly as built. This document exists so that when SOP's own code gets written, the real open questions (§4/§5) get resolved deliberately rather than discovered mid-build, and so the two new thin use cases (§0) have an agreed shape before anyone writes them against the GL Engine.
