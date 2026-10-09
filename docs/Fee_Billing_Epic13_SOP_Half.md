# Epic 13: SOP's half. School fee billing in SOP (SPUTO: P, U, T and a proposed order)

**Status: DRAFT, 2026-10-09, SOP session.** The SOP half of `docs/Fee_Billing_Epic13_SPUTO_Scope.md` (the **S**), alongside `docs/Fee_Billing_Epic13_GL_Posting_Rules.md` and `docs/Fee_Billing_Epic13_EA_Identity_Leg.md`. **Design only: no code is started** until CM publishes the dependency order and Femi has answered the section 11 decisions. Grounded in SOP `origin/master` (task definition :46), the ER code read on 2026-10-07 (`FeeService`, `SopEventEnvelope`, the in-memory and Exposed outbox publishers), the ER spec (`FIN-INT-001..020`, `ER-FEE-001..014`, UC-13, UC-14) and the other halves. **FACT** = read from code or a source document. **RECOMMENDED** = SOP's proposal. **OPEN** = someone else's decision.

**Designed against these standing decisions** (so none is re-opened here): multi-Tenant on one deployment, always intended (the Tenant is derived from the Company per request; two walls: Tenant against Tenant and Company against Company inside one Tenant; `docs/T15_SOP_Statement.md`); RBAC v0.2/0.3 (a service principal may **enter** but never **approve**; service-originated money acts carry an `actedBy` block; approvals are by a human with the approve capability, the Owner exempt from creator-differs-from-approver and flagged); SOP's own idempotency pattern (claim-first, owner token, three release modes, derived keys); services recognise revenue when the invoice is recorded (Femi, 2026-10-07: "Services Invoice recognise revenue immediately"), so **no deferred-income build** unless D1 reverses it.

## 1. The problem, restated for SOP

ER holds fee invoices and payment confirmations in its own tables. Marking an invoice paid and enrolling a student write events to an ER outbox that **nothing delivers** (FACT, confirmed 2026-10-07), so no fee reaches SOP or the ledger. The decided direction (ER MVP definition, 2026-10-01; Femi, 2026-10-07): **SOP is the system of record for school billing**, extended; ER narrows to **fee rules and clearance policy** and consumes SOP's events; SOP posts to GL. One school = one EA Company = one SOP entity, keyed by the Company id (EA identity leg, section 1).

SOP today has `Customer`, `SalesOrder`, ordinary and cash sales, collections against an order, invoice PDFs and email, Company-scoped access and client idempotency (FACT). It has **no** billing account, fee schedule, bulk run, per-school sequential numbering, payment record, allocation, receipt, statement or event inbox/outbox. The SOP `SalesOrder` is order-to-cash shaped (aval gate, delivery terms, one total, cumulative `collectedAmount`): it is the wrong aggregate for fees (RECOMMENDED: a new billing context beside it, section 3).

## 2. Scope of this half

**In:** billing accounts and student sub-accounts; fee schedules (billing items and prices by version); bulk billing runs with dry run; fee invoices (numbering, lines, VAT category, GL posting); payments, allocation, receipts and receipt numbering; adjustments (waivers, discounts, credit notes, refunds, write-offs, voids); balances, ageing and statements; the inbox that de-duplicates by event id and the outbox that delivers SOP's events; the API and event contract in both directions; reconciliation support; what SOP needs from GL and the others.

**Out (own items):** parent payment gateways and the payment session API (separate spec; the contract reserves the hook), exam registration beyond pass-through, FX, dashboards (FIN-INT-016/020), offline receipt ranges (FIN-INT-013, needs ER's local-first sync; a hook is reserved), consolidation across a group's Companies (not now, per Femi), split billing across several payers (v1 is one payer per student at a time; see Q5), clearance policy (ER's).

## 3. The SOP model (RECOMMENDED)

Every table carries `entity_id` (the school's Company) as its own column, and every repository method takes the Company (T15 rule). Money is `Money` (amount plus currency, one currency per Company).

| Aggregate | Purpose | Key facts |
|---|---|---|
| `BillingAccount` | The payer or family account | `(entity_id, payer_ref)` unique, where `payer_ref` is ER's guardian-account id; links to the SOP `Customer` created at guardian resolve (so GL's AR dimension `CUSTOMER` is the payer); status OPEN, CLOSED; currency |
| `StudentAccount` | The student sub-account | `(entity_id, student_ref)` unique (idempotent on the ER student id, FIN-INT-002); belongs to one BillingAccount at a time; status ACTIVE, SUSPENDED, WITHDRAWN, GRADUATED with effective date; billing-relevant snapshot (level, arm, campus, boarding) |
| `FeeSchedule` and `FeeScheduleItem` | Billing items and prices by version | `(entity_id, session, term, version)`; items: code, name, **kind** `FEE` / `GOODS` / `PASS_THROUGH`, amount, vat category, **revenue role** (a role such as TUITION, resolved to a GL account through GL's role mapping, never a stored account id), mandatory or optional; **published versions are immutable**, a change is a new version (FIN-INT-004) |
| `BillingRun` | One bulk run | `run_id` is ER's idempotency key; term, scope, `dryRun`, state REQUESTED, PREVIEWED, RUNNING, COMPLETED, PARTIAL, FAILED; counters and totals by item and level; list of exceptions |
| `FeeInvoice` | An invoice | per-school sequential number; BillingAccount, StudentAccount, run id (nullable for individual invoices), **kind** `FEE` or `GOODS` (never mixed on one invoice), lines (item code, description, quantity, unit price, vat category, revenue role), net, VAT, gross, due date, status DRAFT, ISSUED, PART_PAID, PAID, CANCELLED; GL journal id; source event id |
| `FeePayment` and `PaymentAllocation` | A payment and where it went | per-school sequential **receipt number** assigned at recording; channel CASH, BANK_TRANSFER, POS, MOBILE_MONEY, GATEWAY; external reference; received date; amount; status RECEIVED, ALLOCATED, REVERSED, VOID; allocations (invoice, amount); unallocated remainder = parent advance; recorded by and `actedBy` |
| `FeeAdjustment` | Waiver, discount, credit note, refund, write-off | type, amount, invoice or account, **approver reference**, reason, GL journal id |
| `BillingEntry` | Append-only account ledger | signed amounts per account and student for INVOICE, PAYMENT, ADJUSTMENT, REVERSAL; balance and ageing are derived from it; every posting writes one |
| `DocumentSequence` | Gapless numbering | `(entity_id, kind)` counter incremented under a row lock **inside the transaction that inserts the document**; documents are never deleted, only voided with a reason |
| `EventInbox` / `EventOutbox` | Delivery | inbox unique on `(entity_id, producer, event_id)` with the stored result; outbox rows per event with state and attempts |
| `GlPostingOutbox` | Reliable posting | a document is saved first with its number, then posted to GL by a worker using a derived idempotency key; status POSTED stores the journal id |

**Why document first, post second (a deliberate difference from the sale flow).** A receipt or invoice number must never be lost or skipped, and a 1,000-invoice run must be resumable. So the SOP document is the record, the GL posting is a reliable second step with the same retry discipline as everything else; `InvoiceIssued` and `PaymentReceived` are emitted only **after** GL accepted the posting (the ER spec says "invoice posted"). A posting GL refuses 4xx leaves the document in POSTING_FAILED with the reason, visible to the Bursar and retried only by a person; it is never silently dropped.

**Student against payer in the ledger.** GL records the payer (`CUSTOMER` dimension, the SOP Customer behind the BillingAccount); the per-student balance lives only in SOP (GL half, D5). SOP reconciles the sum of its student balances per payer to GL's customer balance.

**Goods and fees on separate invoices (GL's constraint).** One taxable line refuses a whole GL invoice, and a school's goods (uniform, books) are usually standard-rated while tuition is exempt. So an invoice has one `kind`; a run issues up to two invoices per student per term (FEE, GOODS), and a country without a verified VAT schedule can bill FEE (all-EXEMPT, GL's exempt-only path) but **cannot publish a schedule containing a non-exempt item**: schedule publication checks the Company's allowed categories against GL's VAT-categories route and rejects the rest with the item named.

## 4. Requirements (P)

IDs `FR-SOPFEE-nn`; the FIN-INT / ER-FEE numbers they serve are in brackets.

**Identity and access**
- FR-SOPFEE-01 Every billing route is Company-scoped in the path (`/api/companies/{companyId}/...`); the Tenant is derived from the Company (T15); a Company outside the caller's, or outside a service credential's Company set, is 403/404. (FIN-INT-001, -017)
- FR-SOPFEE-02 The Bursar is a `SALES_OFFICER` with the `SOP` module at `WRITE` at the school's Company (EA identity leg): records invoices' effects and payments. **Void, waiver, refund and write-off need the approve capability** held by the Owner Admin or his delegate; the creator may not approve (the Owner is exempt and flagged). (ER-FEE-009)
- FR-SOPFEE-03 A service principal (ER) may submit instructions but never approves; every service-originated money act stores the origin's `actedBy` {user id, role at origin} beside the service identity. (RBAC B3, P9)

**Billing accounts and students** (FIN-INT-002/003)
- FR-SOPFEE-04 `StudentEnrolled` creates or links the BillingAccount (by `payer_ref`) and the StudentAccount (by `student_ref`), idempotently; the SOP Customer for the payer is created or linked at the same time if missing.
- FR-SOPFEE-05 `StudentUpdated`, `StudentStatusChanged` and `FeePayerChanged` update, re-assign or close accounts; WITHDRAWN or GRADUATED stops future billing and produces a final statement; billing-relevant changes re-rate **future** invoices only.

**Fee schedules** (FIN-INT-004/015)
- FR-SOPFEE-06 `FeeScheduleChanged` creates a new schedule version with its items; a published version is immutable; a missing role-to-account mapping blocks publication (the run would block anyway, UC-13 E4).
- FR-SOPFEE-07 Price authority is SOP's published version: a run instruction naming an item or price that is not in the version is an exception, never invoiced at ER's price.

**Billing runs and invoices** (FIN-INT-005, ER-FEE-001/002)
- FR-SOPFEE-08 `BillingRunRequested` creates a run idempotently on `run_id`; instructions arrive in batches (ER computes each student's applicable items from its rules, siblings and approved waivers); a **dry run** returns counts and totals by item and level and the exceptions and creates no document.
- FR-SOPFEE-09 A run is resumable and idempotent per invoice: invoice identity is `(run, student account, kind)`; a retried or duplicate batch creates nothing new; a student with no account or payer is listed as an exception and the run continues.
- FR-SOPFEE-10 Individual invoices (late enrolment, supplementary invoice after a schedule change, UC-13 A1/A2) use the same code path with a source event id as the idempotency identity.
- FR-SOPFEE-11 Each invoice has a per-school gapless sequential number, one `kind`, a due date, line-level VAT category (EXEMPT for fees and pass-through; goods per the schedule), and posts to GL as **one** journal entry with one credit account per line (GL G2); the entry description starts with the invoice number and SOP stores the returned journal entry id. (ER-FEE-013, FR-GLFEE-02/03/11)
- FR-SOPFEE-12 `InvoiceIssued` is emitted after the posting succeeds, once per invoice, with its lines.

**Payments and receipts** (FIN-INT-006/013/007, ER-FEE-003/004/010)
- FR-SOPFEE-13 A payment is recorded by a person (cash at the bursary, a bank transfer, POS) or arrives as an event (gateway, mobile money, later); it gets a per-school sequential receipt number at recording, an external reference for matching, and is idempotent on `(channel, external reference)` or the Idempotency-Key.
- FR-SOPFEE-14 Allocation defaults to the account's oldest open invoice first, caller-overridable; an unmatched payment goes to an exceptions queue for manual allocation (UC-14 A1); an overpayment becomes a parent advance (UC-14 A2), applied to the next invoice or refunded (GL G5).
- FR-SOPFEE-15 A receipt is a PDF in the same renderer as invoices, retrievable by number; a cancelled receipt is **voided with a reason, never deleted**, and the void reverses the GL entry (GL G8); `PaymentReversed` is emitted.
- FR-SOPFEE-16 Posting a payment to GL uses the channel's role mapping (CASH, BANK, MOBILE_MONEY_CLEARING, GATEWAY_CLEARING, POS_CLEARING); `PaymentReceived` is emitted after the posting succeeds.

**Adjustments** (FIN-INT-008/010, ER-FEE-006/012)
- FR-SOPFEE-17 `WaiverApproved` and refund requests are applied as `FeeAdjustment`s carrying the approver reference; a waiver posts Dr scholarship or discount, Cr AR (works today for exempt fees); a refund posts Dr advance or AR, Cr settlement (GL G7); a write-off Dr bad debt, Cr AR (generic journal in v1).
- FR-SOPFEE-18 Pass-through items (PTA, exam registration) post to LIABILITY credits, not revenue, and appear as their own lines; remittance is a generic journal (out of scope here). (FIN-INT-010/019)

**Balances, statements, reconciliation** (FIN-INT-009/012, ER-FEE-005)
- FR-SOPFEE-19 Every posting writes a `BillingEntry`; balance, overdue amount and ageing are derived; `AccountBalanceChanged` is emitted after any posting that changes a balance, per account, in order.
- FR-SOPFEE-20 SOP serves balances, statements per payer or student, the receipts list and an as-at **reconciliation summary** (counts and totals of accounts, invoices, payments, balances, with a content hash) that ER compares in its daily job; SOP also checks the sum of student balances per payer against GL's customer balance and reports a discrepancy.

**Delivery** (FIN-INT-011/014)
- FR-SOPFEE-21 Inbox: every inbound event is stored with its result, de-duplicated by `(entity_id, producer, event_id)`, and processed in `sequence` order per `account_key`; a duplicate returns the stored result.
- FR-SOPFEE-22 Outbox: every outbound event is written in the same database transaction as the change that caused it, delivered by a worker with retry and backoff, kept as FAILED after the retries, and replayable by an administrator (administer capability) through an audited route.
- FR-SOPFEE-23 The contract is versioned (`schemaVersion`), additive within a version, with contract tests in CI on both sides and at least six months' deprecation notice. (FIN-INT-014)

**Non-functional**
- NFR-SOPFEE-01 Throughput: a 1,000-student run is about 1,000 to 2,000 invoices a term; the run is chunked, resumable and measured with a 1,000-invoice test against real Postgres before the pilot; a GL batch route only if measurement says so.
- NFR-SOPFEE-02 Isolation: the tests in section 9 (Tenant against Tenant, Company against Company) pass before any real school is added.
- NFR-SOPFEE-03 Nothing is logged that identifies a student or payer beyond ids; student names are not required in events except where a statement needs them (Q8).

## 5. The transport (CM's proposal in the scope doc, section 5): confirmed with four amendments

**Confirmed:** HTTPS push from each producer's transactional outbox to the consumer, with an inbox that de-duplicates by event id; no new infrastructure; a queue can replace it later behind the same contract. **Amendments:**
1. **Typed JSON with `schemaVersion`.** ER's current envelope carries `payload: Map<String,String>` (FACT); money and lists need typed fields. The envelope is `{eventId, type, schemaVersion, occurredAt, companyId, accountKey, sequence, actedBy?, payload}`, with `companyId` = the school's EA Company id (ER's `organisationId`) and `actedBy` = {userId, role} of the human who triggered it in the origin system.
2. **Per-account ordering is explicit.** `accountKey` is the BillingAccount's `payer_ref` (or the student for student-only events); `sequence` is a producer-side monotonic counter per `accountKey`. The consumer applies in order; a gap answers `OUT_OF_ORDER` for that event and the producer retries in order (it sends per account serially).
3. **Batch delivery and per-event results.** `POST` takes up to 50 events and returns, per event, `ACCEPTED`, `DUPLICATE` (with the stored result), `REJECTED` (with a reason token) or `OUT_OF_ORDER`; one bad event never fails the batch.
4. **A real dead-letter and replay.** FAILED outbox rows are kept; an audited admin route replays one or all (FIN-INT-011); a "stuck" metric (oldest undelivered age) is exposed for CM's alarms.

**ER-side facts this relies on (for the ER half to confirm):** ER's outbox is persistent in `ExposedSopEventPublisher` but **no delivery worker exists** and `OutboxSopEventPublisher` is in-memory; ER must accept SOP's service principal for SOP-to-ER events (EA identity leg, section 3).

## 6. The API and event contract (RECOMMENDED shapes; ER and WEB confirm)

All paths are `/api/companies/{companyId}/...`; every write takes an `Idempotency-Key` unless it carries a natural event id; money is `{amount, currency}` strings; dates ISO.

### 6.1 ER to SOP

| Route | Purpose |
|---|---|
| `POST /inbox/events` | Batch of ER events (below); the service credential must cover this Company |
| `POST /billing-runs` {runId, sessionTerm, scopeNote, dryRun, scheduleVersionRef} | Create or fetch a run (idempotent on `runId`) |
| `POST /billing-runs/{runId}/batches` {batchNo, last, instructions:[{studentRef, kinds:[{kind, items:[{itemCode, quantity?}]}], waiverRefs?}] } | Submit a batch; idempotent per `(runId, batchNo)`; `last: true` closes the run |
| `GET /billing-runs/{runId}` | State, counters, totals by item and level, exceptions, and the dry-run preview |

Events in `/inbox/events`: `StudentEnrolled`, `StudentUpdated`, `StudentStatusChanged`, `FeePayerChanged`, `FeeScheduleChanged`, `WaiverApproved`, `RefundRequested`, `ExamFeeRegistered`, and (transition only) the legacy `StudentPaymentReceived`, recorded as a cash payment against the invoice named, so the strangler can retire `confirmPaymentStub` last. Example `StudentEnrolled` payload: `{"studentRef":"...","payerRef":"...","payerName":"...","payerContact":{"email":"...","phone":"..."},"level":"JSS1","arm":"A","campusRef":"...","boarding":"DAY","startTerm":"2026-T1"}`.

### 6.2 SOP people and screens (WEB), all Company-scoped, WRITE or approve as marked

`GET/POST /billing-accounts`, `GET /billing-accounts/{id}` (balance, ageing), `GET /billing-accounts/{id}/statement?from&to`, `GET /invoices?status&student`, `GET /invoices/{id}` and `/pdf`, `POST /payments` (record), `GET /payments`, `GET /receipts/{number}` and `/pdf`, `POST /payments/{id}/allocate`, `POST /payments/{id}/void` (approve), `POST /adjustments` (waiver, discount, credit note, write-off: approve), `POST /refunds` (approve), `GET /exceptions` (unmatched payments, run exceptions), `GET /reconciliation?asOf=`, `GET /outbox?state=FAILED`, `POST /outbox/{eventId}/replay` (administer).

### 6.3 SOP to ER (delivered to ER's inbox with SOP's service credential)

| Event | Trigger | Payload (key fields) |
|---|---|---|
| `InvoiceIssued` | Invoice posted | `invoiceId, number, kind, studentRef, payerRef, runId?, lines[{itemCode, description, quantity, unitPrice, vatCategory, amount}], net, vat, gross, dueDate` |
| `PaymentReceived` | Payment posted | `paymentId, receiptNo, channel, amount, receivedOn, payerRef, allocations[{invoiceId, studentRef, amount}], unallocated` |
| `PaymentReversed` | Void or bounce | `paymentId, receiptNo, reason, reversedOn` |
| `AccountBalanceChanged` | Any posting changing a balance | `payerRef, studentRef?, balance, overdue, ageing{current,30,60,90plus}, asOf` |
| `RefundIssued` | Refund posted | `refundId, payerRef, amount, reason, approverRef` |
| `BillingRunCompleted` | Run closed | `runId, counts, totals, exceptions[]` |
| `FeeScheduleRejected` | Publish failed (missing mapping, non-exempt item in a country without rates) | `scheduleRef, reasons[]` |

## 7. What SOP needs from GL (maps to GL's G-list)

| Need | GL item | If late |
|---|---|---|
| Exempt-only VAT path for all-EXEMPT invoices in a country without a schedule | G1 | Nigerian and Sierra Leone fee invoices are refused (409 `no_vat_rate_schedule`) |
| One journal entry per invoice with a credit account per line | G2 (FR-GLFEE-02/03) | Fees can only post to one revenue account; pass-through to liability impossible |
| School account pack and the role mapping read (`fee-posting-context`) | G3, G6 | SOP cannot resolve revenue, clearing or advance accounts; the fallback is SOP storing account ids on items (GL advises against) |
| Overpayment split (advance) | G5 | An overpayment is an AR credit balance with no advance account (acceptable for the pilot, wrong for reports) |
| Refund and a reversal route | G7, G8 | No void of a receipt or invoice; **G8 is the first thing SOP needs** |
| Idempotent posting with SOP's derived keys, and the invoice or receipt number in the description | existing and FR-GLFEE-11 | none |
| VAT-categories route per Company | in flight (GL :97) | SOP cannot validate schedule publication |

Release order, as everywhere: SOP declares new GL response fields tolerantly first, GL ships second, SOP behaviour third.

## 8. Use cases (U)

SOP-side flows; the ER spec's UC numbers in brackets.

- **UC-F1 Enrol a student (UC-01):** `StudentEnrolled` creates the payer account, the student account and the SOP Customer idempotently; a duplicate event is a no-op returning the stored result.
- **UC-F2 Publish a fee schedule:** a new version with items; a missing mapping or a non-exempt item in a country without rates rejects it with the item named; published versions are immutable.
- **UC-F3 Dry-run then execute a term billing run (UC-13):** preview with counts, totals by item and level and exceptions; after the Principal's approval in ER the real run submits the same batches; a duplicate `runId` is refused by idempotency (UC-13 E3); a student without an account is an exception and the run continues (E1); GL unavailable leaves documents POSTING_PENDING and the run retries (E2).
- **UC-F4 Late enrolment invoice (UC-13 A1)** and **supplementary invoice or credit note after a schedule change (A2).**
- **UC-F5 Goods and fees:** a student with uniform and tuition gets two invoices; in a country without rates the goods item is rejected at publication, not at invoicing.
- **UC-F6 Record a cash payment at the bursary (UC-14):** receipt number assigned, allocated oldest first, posted to GL, receipt PDF, `PaymentReceived` to ER, balance event.
- **UC-F7 Bank transfer matched by reference; an unmatched payment** lands in the exceptions queue; the Bursar allocates it manually (UC-14 A1).
- **UC-F8 Overpayment (A2):** the excess is a parent advance applied to the next invoice or refunded.
- **UC-F9 Void a receipt (E1):** an approver voids with a reason; the GL entry is reversed; the receipt stays on file as VOID; `PaymentReversed` goes to ER; clearance is re-evaluated by ER.
- **UC-F10 Waiver, scholarship, discount (ER-FEE-006):** ER approves; SOP applies the adjustment with the approver reference and posts it; for an exempt fee no VAT effect.
- **UC-F11 Refund and write-off (ER-FEE-012):** approval required; posted per the mapping.
- **UC-F12 Withdrawal or graduation (FIN-INT-003):** future billing stops; the final statement is produced.
- **UC-F13 Statement and balances (ER-FEE-005):** per payer and per student, as at a date, with ageing.
- **UC-F14 Daily reconciliation (FIN-INT-012):** ER compares its summary to SOP's; SOP compares student balances to GL's payer balance; a discrepancy is surfaced to the Bursar and support.
- **UC-F15 Duplicate and out-of-order delivery:** a duplicate event id is `DUPLICATE`; a gap in `sequence` is `OUT_OF_ORDER` until the missing event arrives.
- **UC-F16 Delivery failure and replay:** the consumer is down; rows stay in the outbox and retry; after the retry budget they are FAILED and an administrator replays them.
- **UC-F17 Isolation:** a user, a service credential or a guessed id from another school or another Tenant sees and changes nothing (section 9).
- **UC-F18 Strangler transition:** ER's legacy `StudentPaymentReceived` is accepted as a cash payment; once ER sends real SOP-originated payments the stub is retired.

## 9. Isolation tests specific to this epic (add to `docs/T15_SOP_Statement.md` section 5)

Billing account, invoice, payment, receipt, run and exception ids of school A1 are 404 under A2 (same owner) and under B1 (another Tenant); a run, batch or inbox event for A1 submitted with a credential scoped to A2 is 403 and creates nothing; receipt and invoice numbers are per Company and never collide or leak a count; the reconciliation summary and statements contain only that Company; the outbox delivers an A1 event only to A1's ER school; replaying A1's events cannot touch A2's.

## 10. Tasks (T) and the proposed order within SOP

Estimates are SOP-side build and tests for one person, excluding review, and are rough.

| # | Task | Depends on | Days |
|---|---|---|---|
| E0 | **Foundations (before any billing code):** S-T1 record the acting identity; the scoped ER credential and Company binding (T15 step 5 / RBAC R7); the `actedBy` convention; T15 data-model steps (Company key on every table) | Femi's go on S-T1; CM's T15 plan; EA internal route | counted in the RBAC and T15 plans |
| E1 | Event envelope, **inbox** (de-duplication, per-account order, results), **outbox** with worker, retry, FAILED state, replay route, stuck metric | E0 | 3 |
| E2 | Billing accounts and student accounts, and the payer SOP Customer link; `StudentEnrolled/Updated/StatusChanged/FeePayerChanged` | E1 | 2.5 |
| E3 | Fee schedules and versions, immutability, publication checks against GL (mapping, VAT categories) | E2, GL G3/G6 and the VAT-categories route | 2.5 |
| E4 | `DocumentSequence`, FeeInvoice, the GL posting outbox with derived keys, invoice PDF, `InvoiceIssued` | E3, GL G1, G2, G8 | 5 |
| E5 | Billing runs: dry run, batches, exceptions, resumability, summary | E4 | 4 |
| E6 | Payments, receipts (number, PDF), allocation, advance, `BillingEntry`, balances and ageing, `PaymentReceived`, `AccountBalanceChanged` | E4, GL G5 | 5 |
| E7 | Adjustments: waiver, discount, credit note, refund, write-off, void (approve capability, creator differs) | E6, RBAC T5a/T8, GL G7/G8 | 4 |
| E8 | Statements, reconciliation summary, SOP-to-GL balance check, exceptions queue | E6 | 2 |
| E9 | Legacy `StudentPaymentReceived` compatibility (strangler) | E6 | 0.5 |
| E10 | Contract tests with ER (both directions) in CI; the 1,000-invoice run; the isolation suite of section 9 | E1 to E8 | 3 |
| E11 | Offline receipt ranges (FIN-INT-013): `ReceiptRange` per registered device, duplicate and gap detection on sync | ER local-first sync | later |
| | **Total (E1 to E10)** | | **about 31.5 days** |

**Order:** E0, then E1 (the delivery foundation: nothing else is testable end to end without it), E2, E3, E4, E5 (invoices and runs); E6, E7, E8 (payments and adjustments); E9, E10; E11 later. Within each step the tests are written first and the first Tenant's regression suite stays green. **Strangler:** SOP becomes the record for **new invoices** first (E4/E5), ER stops creating `FeeInvoice` rows, payments move next (E6), and ER's `confirmPaymentStub` is retired last (E9 then removal on ER's side). One reviewed release per step; consumers tolerant first.

## 11. Decisions and open questions

| # | Question | Owner | SOP's recommendation |
|---|---|---|---|
| D1 | Is **revenue recognised at invoice** for school fees (Femi's rule for services), or deferred when billed before the term? | Femi | At invoice (no G4, no release run); say so per school type in the mapping |
| Q1 | May SOP trust a waiver/refund **approved in ER by a human** (carried as `actedBy` + an approval reference), given "a service never approves"? | CM (RBAC), Femi | Yes, as an attributed instruction from the origin system with the approver's id and role; SOP stores `approved_at_origin_by`. The alternative (approve again in SOP) duplicates the Principal's work |
| Q2 | Invoice and receipt number format (per-school gapless) | Femi, +ER | `INV-{yyyy}-{000001}` and `RCT-{yyyy}-{000001}` per school and year, reset yearly; the sequence is the control |
| Q3 | Allocation default | Femi, Bursars | Oldest open invoice first, overridable per payment |
| Q4 | Late enrolment pro-rata (spec TBC) | Femi, +ER | Not in v1: full-term price, adjusted by a credit note |
| Q5 | **Split billing** across several payers (FIN-INT-003) | Femi, +ER | Not in v1: one payer per student at a time; split later with a `payer_share` table |
| Q6 | A school's role titles beyond Bursar (cashier, finance manager) | EA, Femi | `SALES_OFFICER` for entry, an approve delegation for the finance manager (EA identity leg) |
| Q7 | First pilot school, its country, and whether the exempt-only flag is verified there | Femi | Nigeria first only after the primary-source confirmation (GL D4) |
| Q8 | Do statements need student **names** in SOP? | +ER, Femi (privacy) | Carry a display name on the StudentAccount (needed for a payer's statement), nothing else personal, never logged |
| Q9 | Whether the live switch waits for this epic | Femi | Not SOP's call |

## 12. Risks

- **The GL gaps are the critical path.** Without G2 and G8 SOP can post neither a mixed invoice nor a void; E4 should not start before they are scheduled. SOP can build E1 to E3 while GL builds.
- **Volume in one transaction path.** A run is many independent GL calls; the posting outbox and the 1,000-invoice test are what keep one slow call from blocking a term's billing.
- **Two systems of record during the strangler.** Until ER stops creating invoices there are two; the reconciliation (E8) and a hard cut-over date per school are the control.
- **Gapless numbering versus failed posting.** Numbers are allocated at recording and never reused; a failed posting is a visible POSTING_FAILED document, not a deleted one.
- **Strict decoding in both directions.** Every new field is declared by the consumer before the producer sends it; the contract tests enforce it.
- **Approval semantics (Q1)** can reshape E7 if CM rules that approvals must be made in SOP.
