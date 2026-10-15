# SOP: third-party payments and Discounts Given (SPUTO note)

**From:** SOP session. **Date:** 2026-10-13. **Status:** DRAFT for Femi's approval, docs only, no code until approved (CM). **Decisions it implements** (Decisions_Log 2026-10-13): a third party paying an invoice does not change the customer, the third party is the PAYER of a collection; SOP adds third-party payments to its order processing as a generic capability; scholarships, waivers and price reductions are treated as accountants treat business discounts (Discounts Given). **Written against** SOP master (V18) and GL's half (`Sales_Returns_Credit_Notes_GL_Half.md` section 2.4, accounts 4910/4920, `kind` DISCOUNT, `discountAmount` on `record-collection`). First consumer: the Education Runtime (Playbook UC-E7, PL-FEE-14).

## 1. Scope (S)

Both features change what a **collection** is and what a customer sees, so they share one foundation.

**The gap in SOP today.** An order keeps ONE running `collectedAmount`. There is no record of an individual payment: no date, no payer, no reference, no account, no journal entry id. So SOP cannot say who paid, cannot print a receipt for one payment, cannot produce a truthful customer statement (the sitting finding), and a third-party payer has nowhere to live. Two more facts: a collection larger than what is owed is accepted silently (the order just becomes COLLECTED), and SOP has no discount concept at all (GL has none either until its S8).

**In scope:** a per-payment ledger (foundation), the payer on a collection, several payers and partial payments on one invoice, receipts and statements showing who paid, reversal of a third-party payment (design only), trade discounts on sale lines, discount credit notes after invoicing, settlement discounts at collection.
**Out of scope:** a Party/sponsor master record (EA has none; the payer is data on the collection), sponsor pledges before payment (open, below), sponsor-level reports (the data will support them), foreign-currency payments, payment-provider channels.

## 2. Plan / SRS (P)

### 2.1 Foundation: the collection ledger
- **FR-TP01 (M)** New table `sales_order_collections`, one row per collection: id, sales order id, Company, amount, currency, date, settlement account id, GL journal entry id, discount amount, payer fields (2.2), recorded by (the person), recorded at, idempotency key. Written in the SAME transaction as the order's new collected total, only after GL accepted the posting.
- **FR-TP02 (M)** `collectedAmount` on the order stays, as the sum of its non-reversed rows plus an "earlier, not itemised" opening figure for orders collected before this release (those show as one row kind LEGACY, no payer, no account).
- **FR-TP03 (M)** A collection that would exceed what is still owed (gross, else net, minus collected, minus discounts) is refused: 409 `exceeds_outstanding` with the outstanding amount. (Behaviour change: today it is silently accepted. Consumers are told first.)

### 2.2 The payer
- **FR-TP10 (M)** `POST /api/sales-orders/{id}/collections` gains optional `payerName` (1 to 100 characters), `payerReference` (up to 100, for example the transfer or cheque reference) and `payerRelationship` (SPONSOR, EMPLOYER, INSURER, CHARITY, OTHER). All absent = the customer paid. If any is present, `payerName` is required (400 `payer_name_required`).
- **FR-TP11 (M)** The order's customer never changes, and GL's receivable is credited against that customer exactly as today (the customer balance falls by the payment whoever paid).
- **FR-TP12 (M)** GL receives the payer only in the collection's existing description: "Payment by {payerName} ({relationship}), ref {payerReference}, invoice {number}", built by SOP (the caller's own description is appended). No GL change.
- **FR-TP13 (M)** Several payers on one invoice are several collections, each with its own payer; partial payments are allowed; the order is COLLECTED when the total reaches what is owed.
- **FR-TP14 (S)** Payer data is free text for now (no Party record exists). A later Party record would link by id without changing these fields.

### 2.3 What people see
- **FR-TP20 (M)** `GET /api/companies/{c}/sales-orders/{id}/collections` lists the order's collections: id, date, amount, discount, payer (name, relationship, reference or "customer"), recorded by, GL journal entry id, and the order's outstanding amount.
- **FR-TP21 (M)** A receipt (data for the screen to print) per collection: invoice number, customer, amount, date, "Paid by {payer} on behalf of {customer}" when a third party paid, discount allowed, balance remaining after it. Receipt numbers: the collection id now; a gapless per-Company number is Epic 13's design and arrives with it.
- **FR-TP22 (M)** The customer statement (a later build on this ledger) lists invoices, payments with the payer shown, discounts and credit notes, and ends with GL's balance. Statements stay blocked until FR-TP01 exists; they are NOT part of the first build.

### 2.4 Reversal of a third-party payment (design only, not first build)
- The money goes back to the PAYER, not the customer. A reversal row references the collection and keeps the payer; GL must post the reversal of a collection (a reversal route GL does not have today: ask for it in GL's playbook). The order's collected total falls and the order reopens. SOP route when built: `POST .../collections/{collectionId}/reversal`, WRITE, with a reason and the same idempotency rules. Refunding in cash is a payment, outside this note.

### 2.5 Discounts Given (GL's accounts 4910/4920 and legs, section 2.4 of its half)
- **FR-DG01 Trade discount at the sale (M):** each line on `POST /api/sales` and `POST /api/sales-orders` may carry an optional `discountAmount` (money off the line, at most the line's gross, in the order's currency). The line's net is quantity x price minus the discount, VAT is charged on that net, GL receives the smaller net (no GL change, as GL's note says) and the stored line keeps price, quantity AND discount so the invoice shows gross, discount and net. A percentage is the screen's job (it computes the amount).
- **FR-DG02 Discount credit note after invoicing (M):** a waiver, scholarship or price reduction after invoicing is a credit note of kind DISCOUNT: no goods come back, no stock leg. It rides the returns design (`Sales_Returns_Credit_Notes_SOP_Half.md`): lines picked from the invoice, an amount up to what is still unreduced, posted through GL's `record-sales-return` with `kind=DISCOUNT` (Dr Discounts Given), VAT reversed per category exactly as for a return. It cannot be built before the returns Playbook and GL's S8.
- **FR-DG03 Settlement discount at collection (M, needs GL S8):** the collection request gains optional `discountAmount`; `amount` stays what was received; SOP passes both to GL's `record-collection` (`discountAmount`); the order's outstanding falls by amount plus discount; the receipt shows the discount. Whether VAT is reduced by a settlement discount is open for the accountant (GL's note); SOP posts what GL says and decides nothing.
- **FR-DG04 (M):** discounts never touch the customer, the payer or the VAT category of a line; the category copy on the line is still what GL is told.

## 3. Use cases (U)
- **UC-TP1 Sponsor pays an invoice in full:** fee 600.00 against the guardian; the sponsor pays 600.00 with reference "BANK-5521". One collection, payer "St Mary's Fund", SPONSOR. The guardian's balance is 0, the invoice COLLECTED, the receipt says "Paid by St Mary's Fund on behalf of {guardian}".
- **UC-TP2 Several payers:** employer pays 400.00, the customer pays 200.00 on the same invoice: two collections, two payers, one COLLECTED order.
- **UC-TP3 Overpayment refused:** 650.00 offered against 600.00 owed: 409 `exceeds_outstanding` (600.00), nothing posted.
- **UC-TP4 Retry:** the same Idempotency-Key and body returns the same collection and posts nothing twice; the payer is part of the request fingerprint, so a changed payer under the same key is 422.
- **UC-TP5 Statement:** invoice 600.00, payment 400.00 by the employer, payment 200.00 by the guardian, discount 0, closing balance 0.00.
- **UC-TP6 Reversal:** the sponsor's bank bounced the transfer: the collection is reversed, GL reverses the entry, the invoice shows 600.00 owed again.
- **UC-DG1 Sibling discount at billing:** line 500.00 less 50.00: invoice shows 500.00, discount 50.00, net 450.00; GL books 450.00.
- **UC-DG2 Scholarship granted after billing:** discount credit note of 200.00 on a 600.00 invoice: Dr Discounts Given 200.00, Cr receivable 200.00; the guardian owes 400.00.
- **UC-DG3 Early-payment discount:** 590.00 received against 600.00: collection 590.00 with discount 10.00, the invoice is COLLECTED.

## 4. Tasks (T)
| # | Task | Size | Depends on |
|---|---|---|---|
| T1 | Foundation: V19 `sales_order_collections` (+ legacy opening figure), write inside the collection transaction, overpayment refusal, integration tests | 1.5 d | approval |
| T2 | Payer fields, description for GL, list route and receipt data, isolation tests, fixtures (consumer-first: additive, but the overpayment refusal is announced first) | 1.5 d | T1 |
| T3 | Trade discount on lines (V20, create/sale routes, invoice document, PDF) | 1 d | approval |
| T4 | Settlement discount at collection | 0.5 d | GL S8 |
| T5 | Discount credit note | 1 d on top of the returns build | returns Playbook, GL S8 |
| T6 | Customer statement | 1.5 d | T1 |
| T7 | Reversal of a collection | 1 d | GL reversal route |
Total about 8 days; the first useful release (T1 + T2) about 3 days.

## 5. Order (O)
1. **T1 first** (foundation, and the only thing that makes statements possible). 2. T2 (the sponsor case Femi asked for). 3. T3 (independent, no GL dependency). 4. After GL's S8: T4, T5. 5. T6, then T7 when GL has the reversal. **Consumer-first for every response change:** CM, EA, WEB and ER are told the exact fields before any release; a new field is optional; the new list route is additive.

## 6. Open for decision (put in CM's batch)
- **Q-TP1 Overpayment:** refuse (recommended) or allow and record a customer credit? Recommended: refuse until a customer-credit concept exists.
- **Q-TP2 Sponsor pledge before payment:** is it its own receivable? Recommended: no, not in this build; a pledge is a promise, not a debt of the customer.
- **Q-TP3 Payer identity:** free text now (recommended) or a Party record first.
- **Q-DG1 Settlement discount and VAT:** the accountant's rule per jurisdiction (GL's open question); SOP follows GL.
