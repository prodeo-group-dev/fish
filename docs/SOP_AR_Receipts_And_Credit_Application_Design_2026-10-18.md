# SOP receivables: the receipts register and credit-note application, design (SOP session, 2026-10-18)

**Status: design note, docs first, nothing built.** Items 2 and 3 of `SOP_Accounts_Receivable_Completeness_Assessment_2026-10-18.md`: they are the foundation of open items, ageing, statements and the dashboard summary. Order accepted by CM; this note exists because it changes the meaning of "open" and "collected" on a live path, so the rules below are stated before any code.

## 1. Facts (read in code at master `6de3d08`)

- A `SalesOrder` keeps `collectedAmount` (one cumulative `Money`) and `grossAmount` (what GL posted to receivables). `recordCollection(amount)` adds to the total and sets `COLLECTED` when the total reaches the gross (or the net when the gross is unknown), else `PARTIALLY_COLLECTED`. It refuses a non-positive amount, a currency mismatch, and any status but `INVOICED` or `PARTIALLY_COLLECTED`. **It does not refuse an amount larger than what is left.**
- The collection use case posts to GL first and saves the order only if GL accepted (a refused post leaves the order as it was).
- No individual receipt is stored: no date, settlement account, ledger entry id or description survives. Two part payments are indistinguishable from one.
- `IssueCreditNoteUseCase` posts a sales return to GL and issues the credit note; its only effect on the order is to cancel it when every line is returned in full. A credit never reduces what the customer owes in SOP.

## 2. The model

**Receipt** (value object inside the `SalesOrder` aggregate, persisted with it in the same transaction): `id`, `amount` (positive), `currency`, `receivedOn` (the collection date), `settlementAccountId`, `journalEntryId`, `description`, `recordedAt`, `source` (`RECEIPT`, or `LEGACY` for the backfill). One row per collection call. A replay of the same Idempotency-Key never adds a second (the stored response is returned before the use case runs; the ledger entry id is also unique per Company as a second guard).

**Credit application** (value object, same aggregate): `creditNoteId` (unique), `amount`, `appliedAt`. Added when a credit note is issued against a return of this order. Unique on the credit note, so retrying the issue cannot apply twice.

**Derived, never stored twice:** `collectedAmount` = sum of receipts (the existing column stays and is kept equal, for old readers); `creditedAmount` = sum of applications; **`openAmount = gross - collected - credited`**. `gross` is GL's posted gross, else the net total (the existing rule).

## 3. Rules (each is a decision, flagged where it changes today's behaviour)

1. **A collection larger than the open amount is refused** (`409 collection_exceeds_open_amount`, nothing posted). Today it is accepted and silently overpays. Unapplied cash (a customer paying in advance or twice) is a later, separate concept; until it exists, refusing is the only way to keep the subledger equal to the ledger. **Behaviour change; needs CM's/Femi's yes.**
2. **A credit note may exceed the open amount**: if the customer already paid and the goods come back, `openAmount` goes negative and means "a credit balance owed to the customer". It is not floored; ageing shows it separately and never nets it into a bucket. A credit larger than the invoice's gross is refused.
3. **Status keeps its names, with one precise meaning**: `COLLECTED` = nothing left to collect (`openAmount <= 0`), `PARTIALLY_COLLECTED` = something was received or credited and an amount is still open, `INVOICED` = untouched. A credit that clears the invoice with no money received therefore shows `COLLECTED`; the receipts list and `creditedAmount` say why. (A new status would ripple through every reader; not worth it.)
4. **The "paid" flag** on the sale response stays "fully settled" (`openAmount <= 0`), always computed from the stored order.
5. **Cancelled orders** carry no open amount (nothing owed).

## 4. Migration (additive, next free version after `V19`)

- `sales_order_receipts` (order id, receipt fields, `source`), `sales_order_credit_applications` (order id, credit note id unique, amount, applied at).
- Backfill: every order with `collected_amount > 0` gets **one `LEGACY` receipt** for that total (date = the order's creation date, no ledger entry id, because the real dates were never kept). Every issued credit note whose return request belongs to an order gets an application. Existing data is test data until Live, but the backfill is written as if it were not.
- Nothing is removed or renamed.

## 5. API (additive; old shapes keep working)

- The invoice read route and the Sales list rows gain `openAmount`, `creditedAmount` (plain decimals, currency as today). The invoice read route also gains `receipts: [{ id, amount, receivedOn, journalEntryId, description }]`.
- `POST /api/sales-orders/{id}/collections` answers as today; the new refusal is `409 collection_exceeds_open_amount` (rule 1).
- No new route yet; ageing, statements and the reconciliation read the same data later.

## 6. Tests first

Domain: two part payments are two receipts and the sum equals `collectedAmount`; an over-collection is refused and changes nothing; a credit of 20 on a 100 invoice leaves 80 open; a credit after full payment leaves -20 (credit balance); the status after each mix; a duplicate credit note id is ignored. Use case: a refused GL post stores no receipt (as today). Route: refusal body, replay with the same key returns the stored answer and one receipt. Persistence on real Postgres: receipts and the order commit together; the migration backfills a legacy order with a collected total and one with an issued credit note. Golden: the sales list and invoice read fixtures change additively and the contract fixtures in fish-contracts are updated with the consumers told first.

## 7. Estimate and order

Receipts register 1.5 d, credit application 1 d, about 2.5 d together, in one branch because both change `openAmount`. Depends on nothing outside SOP. After it: open items and ageing, the ageing summary EA asked for, then the reconciliation to account 1100.

## 8. Needs a yes before the build

1. Rule 1: refuse an over-collection (recommended).
2. Rule 2: allow a credit balance, not floored (recommended).
3. Rule 3: the meaning of `COLLECTED`/`PARTIALLY_COLLECTED` as above (recommended).
