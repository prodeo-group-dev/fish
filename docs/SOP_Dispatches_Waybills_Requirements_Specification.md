# SOP — Dispatches, Waybills & Delivery Notes: Requirements Specification

**Version:** 0.1 (draft)
**Date:** 2026-09-15
**Author:** Code Reviewer (for Femi), from design ask via Chief of Staff
**Status: draft — not scheduled for build.** Outbound logistics documents in Sales Order Processing as the counterpart to POP Order Fulfillment (waybills, receive-line, fulfillment list).
**Related:** `docs/Sales_Order_Processing_DDD_Design.md` (UC-SO3–SO5, revenue recognition point); `docs/Purchase_Order_Processing_DDD_Design.md`; `docs/IFRS_GL_Posting_Matrix.md` §B.1; `docs/Returns_Inwards_Requirements_Specification.md` FR‑RI1; POP `AttachWaybillUseCase` / `PurchaseOrderFulfillmentRoutes`; SOP `SalesOrder.fulfillLine` / `ImGateway.recordGoodsIssue`.

**Out of scope:** implementing code; supplier returns outwards (stays POP); making IM the owner of commercial shipping documents.

---

## 1. Purpose

Define requirements for **outbound fulfillment documents** on Sales Orders:

- **Dispatch** (commercial act of shipping / releasing goods against an SO)
- **Waybill** (carrier / consignment evidence attached to a dispatch)
- **Delivery Note** (customer-facing / returns-eligible document of what was shipped)

…so SOP mirrors what POP already provides on the inbound side, without duplicating Inventory Management’s physical goods-issue and COGS postings, and without incorrectly coupling every warehouse movement to revenue.

---

## 2. Problem / current state (baseline)

Assessed 2026-09-15 on PRODEO1:

| Capability | POP (inbound) | SOP (outbound) |
|------------|---------------|----------------|
| Fulfillment list / work queue | **Built** (`ListPurchaseOrdersForFulfillmentUseCase`, Fulfilment UI) | **Missing** |
| Waybill attach | **Built** (`AttachWaybillUseCase`, `Waybill`, supplier portal) | **Missing** |
| Line receive / issue orchestration | **Built** (`ReceivePurchaseOrderLineUseCase` → IM) | Partial: `fulfillLine` + `recordGoodsIssue` on ordinary-sale paths; **no** dispatch/waybill/DN documents |
| Returns dispatch to supplier | **Built** (`DispatchReturnOutwardsUseCase`) | N/A (outbound customer returns = Returns Inwards, separate) |
| Delivery Note as return source | — | **FR‑RI1** wants Delivery Note; document type **missing** |

SOP DDD deliberately said UC-SO4 “references IM, doesn’t duplicate it” and only moves SO status — while POP’s *docs* said the same for receipt, then POP+WEB grew waybills/fulfillment. This spec closes that asymmetry on the sales side.

GL legacy `SalesOrder.deliverLine()` (AR+COGS at delivery) was removed; SOP is source of truth for sales orders (2026-09-01).

---

## 3. Stakeholders

- **Warehouse / logistics** — record dispatch, attach waybill, print Delivery Note
- **Sales ops** — see fulfillment queue, progress PartiallyFulfilled → Fulfilled
- **Finance / accountant** — revenue and COGS at the correct IFRS points (not “whenever someone clicked ship”)
- **Customer service** — Delivery Note for returns eligibility (FR‑RI1)
- **Trade-finance / CFO** — aval gate before any fulfillment/dispatch (FR‑SO03)
- **Auditors** — shipping evidence linked to SO, invoice, and inventory issue

---

## 4. Goals and non-goals

### 4.1 Goals

- **G1**: SOP owns **commercial outbound documents** (Dispatch, Waybill, Delivery Note) and **orchestrates** IM goods issue — parallel to POP waybill + receive-line.
- **G2**: Aval gate (FR‑SO03) blocks dispatch/fulfillment the same way it blocks `fulfillLine` today.
- **G3**: Returns Inwards can select a **Delivery Note** as source (FR‑RI1).
- **G4**: Revenue recognition follows **IFRS 15 control transfer**, driven by contract / delivery terms — see §5 (may coincide with dispatch for many terms; must not be hard-coded as “always” or “never”).
- **G5**: COGS / inventory derecognition stays **IAS 2 / IM** on goods issue (or the moment inventory control is lost), coordinated but not merged into a single legacy `deliverLine` blob.
- **G6**: Amend `Sales_Order_Processing_DDD_Design.md` UC-SO4 so design matches this evolved POP-like practice before or with the build.

### 4.2 Non-goals

- IM owning carrier names / waybill numbers as master commercial docs
- A separate Shipping microservice (v1)
- Putting supplier return dispatch on SOP
- Recognizing revenue on destination customer receipt when Incoterms already transferred control earlier (e.g. typical CIF loading)
- Silent auto-post of `RecordSale` on every stock transfer or internal move

---

## 5. Revenue recognition vs dispatch (IFRS 15 / FiSH position)

### 5.1 Standards answer (plain language)

Under **IFRS 15**, revenue is recognised when the entity satisfies a performance obligation by transferring **control** of the promised goods to the customer — not automatically at “warehouse left the building,” and not automatically at “customer signed at door,” unless that event is when control transfers.

**IAS 2** governs inventory/COGS when the entity **loses control of the inventory** (goods issue). That moment is often close to dispatch but is a **separate** posting from revenue when contract timing diverges.

So: *“Shouldn’t revenue be recognised on dispatch/delivery according to IAS?”*

- **Partly yes:** for many common goods sales (e.g. **FOB shipping point / EXW / dispatch = control transfer**), the commercial **dispatch** (or equivalent shipping document date) **is** the IFRS 15 recognition point — revenue *should* be recognised then.
- **Not always:** e.g. **CIF** (as already resolved in SOP DDD §4–§5): control/risk typically transfers at **port of loading** (goods on board) — often evidenced by the outbound shipping/dispatch pack — **not** at destination delivery. Destination delivery later must **not** re-recognise revenue.
- **Bill-and-hold / destination contracts / over-time** (IFRS 15 over-time criteria): recognition may be before or after physical dispatch; dispatch alone is insufficient.
- FiSH already recorded this as **revenue-recognition timing decoupling** (SOP DDD §5 item 5): recognition is **contract-term-triggered**, not delivery-triggered blindly — confirmed as correct IFRS 15 treatment vs legacy `deliverLine()`.

**Governing standard for revenue:** IFRS 15 (control).  
**Not:** a blanket IAS inventory rule that “sale = physical delivery to buyer’s premises.”

### 5.2 Product rule for this feature

- **FR‑REV1**: Each Sales Order (or its `deliveryTerms` / Incoterms profile) has a resolved **Revenue Recognition Point** (already a SOP DDD concept): one of a controlled set, e.g. `ON_DISPATCH` | `ON_LOADING_EVIDENCE` | `ON_DELIVERY_ACCEPTANCE` | `ON_INVOICE_DATE` | `MANUAL_CFO` (exact enum to be finalised; CIF maps to loading/dispatch-evidence, not destination).
- **FR‑REV2**: `RecordSale` / `invoice()` may fire **when the recognition point is satisfied**. If that point is `ON_DISPATCH` (or CIF loading evidenced by the dispatch/waybill pack), dispatch **does** trigger revenue — by policy, not by accident.
- **FR‑REV3**: If recognition point is later than dispatch, dispatch creates logistics docs + may trigger IM issue **without** calling `RecordSale` yet; a later event (acceptance, invoice date, etc.) triggers revenue.
- **FR‑REV4**: Never post revenue twice for the same performance obligation (idempotent recognition keyed to SO line / obligation).
- **FR‑REV5**: WEB must not label every “Dispatch” button as “Recognise revenue”; copy should reflect terms (e.g. “Dispatch — revenue posts on ship” vs “Dispatch — revenue later on acceptance”).
- **FR‑REV6**: Free-text `deliveryTerms` today is insufficient long-term — v1 may map a small Incoterms set; unknown terms → block auto-revenue and require explicit recognition point on the SO.

### 5.3 Sequencing (canonical)

1. Aval confirmed (UC-SO3) — no GL  
2. Dispatch / waybill / Delivery Note (+ `fulfillLine`) — logistics  
3. IM goods issue — inventory/COGS (IAS 2), when inventory control lost  
4. Revenue (`RecordSale`) — when FR‑REV1 point met (may be same wall-clock as 2 for FOB/CIF-loading; may be later)  
5. Collection — unchanged (UC-SO6)

Steps 3 and 4 remain **separate GL crossings** (SOP DDD §4) even when they happen in one operator action (orchestrated use case with two calls).

---

## 6. Functional requirements — documents & orchestration

### 6.1 Dispatch

- **FR‑DI1**: Create Dispatch against a Sales Order (header: SO id, dispatch date, ship-from facility, optional notes).
- **FR‑DI2**: Dispatch lines reference SO lines + quantities dispatched (≤ ordered − previously dispatched − returned, subject to policy).
- **FR‑DI3**: Creating/confirming a Dispatch requires AvalConfirmed (or CFO override path already modelled) — same FR‑SO03 hard gate.
- **FR‑DI4**: Confirming a Dispatch updates SO fulfillment progress (`fulfillLine` / PartiallyFulfilled / Fulfilled) consistently with today’s domain rules.
- **FR‑DI5**: Confirming a Dispatch orchestrates IM `recordGoodsIssue` (or successor) per line when inventory should leave — idempotent; failure leaves SO/dispatch retryable without double issue.
- **FR‑DI6**: When FR‑REV1 says recognition is at dispatch/loading evidence, confirming Dispatch (or attaching required waybill evidence) triggers `RecordSale` / invoice path for eligible lines; otherwise skip revenue here.

### 6.2 Waybill

- **FR‑WB1**: Attach one or more Waybills to a Dispatch: carrier, waybill number, shipped date, optional notes (mirror POP `AttachWaybill` shape).
- **FR‑WB2**: For terms that require shipping evidence before recognition (e.g. CIF loading), FR‑REV2 may require a Waybill (or bill of lading reference) before revenue posts.
- **FR‑WB3**: Waybills are SOP documents; IM is not the system of record for carrier consignment ids.

### 6.3 Delivery Note

- **FR‑DN1**: Issuing a Delivery Note from a confirmed Dispatch (printable / API-retrievable): customer, lines, quantities, dispatch/waybill references, dates.
- **FR‑DN2**: Delivery Note ids are selectable as **return source** for Returns Inwards (FR‑RI1), alongside SO and Invoice.
- **FR‑DN3**: DN quantities drive return eligibility remaining qty (with SO/Invoice as today).

### 6.4 Fulfillment work queue (WEB)

- **FR‑FQ1**: Operator UI list of SOs ready for outbound fulfillment (aval cleared, not fully fulfilled) — parallel to POP Fulfilment tab.
- **FR‑FQ2**: Actions: create dispatch, attach waybill, issue DN, see revenue status (posted / pending recognition point).

### 6.5 Tenancy, audit, idempotency

- **FR‑TX1**: Every dispatch/waybill/DN scoped to tenant/company (entityId) on the SO.
- **FR‑TX2**: Audit: who confirmed dispatch, attached waybill, issued DN; links to IM issue ids and journal ids.
- **FR‑TX3**: Idempotency keys on dispatch confirm and on any RecordSale triggered from it.

---

## 7. Non-functional requirements

- **Compliance:** IFRS 15 control transfer for revenue; IAS 2 for inventory/COGS; Incoterms inform FR‑REV1 mapping.
- **Security / tenancy:** Same SOP auth patterns as existing sales routes; service-account IM calls unchanged in principle.
- **Performance:** Fulfillment list usable at hundreds of open SOs.
- **Usability:** Warehouse can complete dispatch without accounting jargon; finance sees recognition status clearly.
- **Traceability:** From DN → Dispatch → Waybill → SO → IM issue → JournalEntry.

---

## 8. Use case catalogue

- **UC‑OD01**: List orders ready to dispatch (Sales ops / Warehouse)
- **UC‑OD02**: Create and confirm Dispatch (Warehouse) — aval-gated
- **UC‑OD03**: Attach Waybill (Warehouse / carrier desk)
- **UC‑OD04**: Issue Delivery Note (Warehouse / Sales ops)
- **UC‑OD05**: System posts IM goods issue on confirm (System)
- **UC‑OD06**: System posts revenue when recognition point met (System / Finance oversight)
- **UC‑OD07**: Select Delivery Note as Returns Inwards source (Customer service)
- **UC‑OD08**: Finance reviews pending recognition (dispatched, revenue not yet posted)

---

## 9. High-level data model

`SalesOrder` (existing)  
→ `Dispatch` / `DispatchLine`  
→ `Waybill` (0..n per Dispatch)  
→ `DeliveryNote` (from Dispatch)  
→ IM GoodsIssueConfirmation (via gateway)  
→ GL `RecordSale` JournalEntry (when FR‑REV1 satisfied)  
→ Returns Inwards may reference `DeliveryNoteId`

---

## 10. Acceptance criteria

1. Aval-unconfirmed SO cannot confirm Dispatch (unless CFO override path).  
2. Confirmed Dispatch updates fulfillment progress and does not double-fulfill lines.  
3. IM issue is attempted once per dispatch line (idempotent retry safe).  
4. For an SO with recognition point `ON_DISPATCH` (or CIF-loading equivalent), revenue posts when dispatch evidence rules are met — once.  
5. For an SO with later recognition point, Dispatch+DN exist and IM may issue **without** revenue until the later event.  
6. Returns Inwards can pick a Delivery Note and see eligible qty.  
7. No revenue/ledger fields appear for POP-style supplier return dispatch on SOP.  
8. SOP DDD UC-SO4 updated to describe documents + orchestration (not “status only”).

---

## 11. Build status against this spec

| Area | Status (2026-09-15) |
|------|---------------------|
| POP inbound waybill / fulfillment / receive-line | **Built** (reference implementation) |
| SOP `fulfillLine` + aval gate | **Built** |
| SOP → IM `recordGoodsIssue` (ordinary sale paths) | **Built** (partial coverage) |
| Dispatch / Waybill / Delivery Note aggregates & routes | **Not built** |
| Outbound fulfillment WEB queue | **Not built** |
| FR‑REV1 structured recognition point on SO | **Design only** (`deliveryTerms` free-text today; DDD concept exists) |
| DN as Returns Inwards source (FR‑RI1) | **Not built** (FR wants it) |
| Decoupled RecordSale vs issue | **Design resolved**; ordinary-sale path may still couple in practice — revisit when Dispatch lands |

**Suggested build order:** (1) DDD UC-SO4 amendment + FR‑REV1 enum/mapping, (2) Dispatch + waybill + DN API, (3) IM orchestration + idempotency, (4) revenue trigger by recognition point, (5) WEB fulfillment queue, (6) Returns Inwards DN source.

---

## 12. Open questions

1. Exact FR‑REV1 enum and Incoterms → recognition map (confirm CIF loading vs bill-of-lading date).  
2. Must waybill exist before CIF revenue, or is dispatch confirm enough?  
3. Partial dispatch: recognise revenue proportionally per IFRS 15 for that portion when point is ON_DISPATCH? (Default: **yes**, per fulfilled/dispatched qty.)  
4. Services / non-inventory lines on same SO — skip IM issue; recognition rules?  
5. Align ordinary-sale shortcut (`RecordOrdinarySaleUseCase`) with this document model or keep as express path that fabricates an implicit dispatch?
