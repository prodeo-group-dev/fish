# SOP requirement and use-case IDs, for Femi's approval (SOP session, 2026-10-22)

**Status: DRAFT for Femi's approval. Docs only.** Written at CM's request, after the traceability release gate (Decisions Log 2026-10-22: every branch, commit, fix, migration and test case cites a Playbook requirement ID and a use-case ID; CM does not merge or deploy work whose IDs are not in a Playbook approved by Femi). Until Femi approves this file, the IDs below are proposals and the work they describe is UNTRACED by the gate's own rule.

**Written from:** SOP master `b9fe3df` (task definition `:64` per CM for the currency refusal), branch `feature/company-currency-refusal` tip `64ceaf3`, the SOP design notes listed in section 6, `docs/Tax_And_Currency_Jurisdictions_Playbook.md` (TJ-CUR-10, T-TJ-27, UC-TJ-4) and `docs/Fee_Billing_Epic13_SOP_Half.md`. Everything marked **Built** was read in code or tests, not recalled; **deploy status is CM's to state**, not asserted here.

## 0. How the IDs are named, and how they relate to the IDs that already exist

SOP already has three ID families. This file does not replace them; it adds the families that did not exist for the work done since 2026-10-11.

| Family | Covers | Where |
|---|---|---|
| `FR-SO01..09`, `NFR-SO01..05`, `UC-SO1..7` | The goods order-to-cash cycle (customer master, order, aval, fulfilment, invoice, collection, amendment) | `SOP/docs/Sales_Order_Processing_Requirements_Use_Cases.md` |
| `FR-TF-nn`, `UC-TF-01..04` | Bill for Collection / trade finance | `SOP/docs/Trade_Finance_Collection_*.md` |
| `UC-SRS1..8` | Sales returns and credit notes (SOP half) | `docs/Sales_Returns_Credit_Notes_SOP_Half.md` |
| `FR-SOPFEE-01..23`, `UC-F1..18` | The full Epic 13 school billing model (billing accounts, runs, outbox, receipts) | `docs/Fee_Billing_Epic13_SOP_Half.md` |
| **New here:** `FR-SOP-CUR-nn` / `UC-SOP-CUR-n` | Company currency | section 1 |
| **New here:** `FR-SOP-FEE-nn` / `UC-SOP-FEE-n` | The interim fee invoice path (Education Runtime through `POST /api/sales`) | section 2 |
| **New here:** `FR-SOP-AR-nn` / `UC-SOP-AR-n` | Accounts receivable: receipts, credits, overpayment, invoice date, ageing, locks, idempotency | section 3 |

Status words (CM's list): **Built** (in master, tested), **Not built**, **Not in MVP** (deliberately parked, with the reason), **Unclear** (needs a decision or a fact I do not have). "Tip" means the commit that delivers it.

## 1. Company currency: `FR-SOP-CUR` (serves `UC-TJ-15`, `TJ-CUR-10`, `TJ-CUR-6`, `T-TJ-27`, with `UC-TJ-4` as the screen counterpart; Femi's decision, Decisions Log 2026-10-22: "It cannot be hard coded")

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-SOP-CUR-01 | Every money amount a caller sends for a sale, collection, Bill for Collection collection (collected amount and restored headroom) or credit note must be in the Company's own currency, which is GL's `baseCurrency` for that Company. A different currency is refused with `400 currency_mismatch`, naming the field and both currencies, **before** anything is saved, issued at Inventory or posted. | **Built** | `64ceaf3` (orders, trade-finance record-sale, collections, Bill collect, credit notes); `POST /api/sales` built earlier with S1 (`ac54dc9`) from the posting context. |
| FR-SOP-CUR-02 | If SOP cannot read the Company's currency from GL, the call is refused (fail closed), GL's status is relayed as `company_currency_unavailable`, and nothing is attempted. | **Built** | `64ceaf3` |
| FR-SOP-CUR-03 | No currency is hard coded or defaulted anywhere in SOP. | **Built** (no literal currency code in SOP main code; checked 2026-10-22) | grep of `src/main` |
| FR-SOP-CUR-04 | The refusal body is a stable contract with a fixture, declared by every consumer before release. | **Built** | fish-contracts `sop/currency-mismatch-error.json` (`aa579a6`); WEB, EA, ER declared or answered 2026-10-22 |
| FR-SOP-CUR-05 | SOP's service account may call GL's Company read (`GET /companies/{id}`); without it every guarded call fails closed. | **Built** in GL (GL review 2026-10-22: `gl/sop-company-read-allowlist` `1f3054c`, PR 111, merged). **Confirm with one real call from SOP's account after GL's deploy.** GL's own `currency_not_company_currency` check is only a second line once released. | GL review |
| FR-SOP-CUR-06 | A return line's estimated value and a facility's headroom capacity are also checked against the Company currency. | **Not in MVP**: neither posts to the ledger. Revisit if either starts to. | |
| FR-SOP-CUR-07 | **The status code.** The stable contract is the code `currency_mismatch` plus a plain message (Tax playbook, `TJ-CUR-10` as amended). SOP answers `400`, as its sale route always did, and WEB has declared `400`; Payroll shipped `409` (`d4f0fe0`). | **Built as 400; the status itself is parked as `PQ-22`** in the Tax playbook (Tax session's recommendation: leave as built, WEB maps both; CM can settle it without Femi). SOP stays at 400 unless PQ-22 says otherwise. | Tax playbook branch `docs/tax-playbook-id-index` (`c60ee65`, draft) |

**UC-SOP-CUR-1 Sell in a currency other than the Company's** (realises `UC-TJ-15` for SOP). Main: a person (or the Education Runtime) submits a sale or order whose line is in GBP for a Company that books in USD. SOP reads the Company's currency, refuses 400 `currency_mismatch` "lines[0] is in GBP but this Company books in USD"; no order is saved, no stock issued, nothing posted. Alt: every line is in the Company's currency: proceeds as before. (Screen side: `UC-TJ-4`.)
**UC-SOP-CUR-2 GL cannot say what the Company's currency is.** Main: the read fails (GL down, or SOP's account not allowed). SOP refuses with `company_currency_unavailable` and GL's status; nothing is attempted, so the same request can simply be retried when GL answers.
**UC-SOP-CUR-3 Collect or credit in the wrong currency.** Main: a collection, a Bill collection or a credit note arrives in a currency other than the Company's. Refused 400 `currency_mismatch` naming `amount` (or `collectedAmount` / `restoreHeadroomAmount`); the sale and the ledger are unchanged.

## 2. The interim fee invoice path: `FR-SOP-FEE` (serves Decisions Log L104(5), L119, L121; test case `RT3-FEE1`; the full Epic 13 model stays `FR-SOPFEE-nn`)

**Scheduling (CM, 2026-10-22, Femi): Education Runtime work is SUSPENDED until FiSH is stable as a GLaaS. S1 stays as built and live; nothing in this section is scheduled, and no new ER-driven SOP work starts. `FR-SOP-FEE-04` and every Not-built row here are parked, not queued. SOP's GLaaS core (section 3 and section 1) is the priority.**

S1 is deliberately the small path: the Education Runtime raises one CREDIT sale of Inventory **service** items through the existing sale route. It realises, in part, `FR-SOPFEE-03` and `FR-SOPFEE-11` (service principal never approves; line-level VAT category) and the individual-invoice flow of `UC-F4`. It does **not** build billing accounts, runs, receipts or the outbox (`FR-SOPFEE-04..23`).

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-SOP-FEE-01 | The Education Runtime's service credential may raise a CREDIT sale of IM **service** items only, through `POST /api/sales`; a stock item or a cash sale is refused 403. | **Built** (in master) | `ac54dc9` (S1); release/deploy status is CM's. |
| FR-SOP-FEE-02 | It may do so only for Companies on the configured school list. | **Built, interim** (`SOP_ER_COMPANY_IDS`). **Not built**: the EA-backed school rule (S2) that replaces the list. | |
| FR-SOP-FEE-03 | A fee line's VAT category comes from the IM item; an item with no category is refused (409 `item_has_no_vat_category`), never defaulted; the caller does not choose it. | **Built** | S1; Decisions Log L119/L121 |
| FR-SOP-FEE-04 | A fee line posts to the revenue account of its IM item, with Suspense `3910` as the fallback. | **Not built** in SOP. **No longer waits for GL** (GL review: per-line routing is deployed: `lines[].accountId` on record-sale, Suspense fallback, `line_account_*` errors, `?usableFor=sale-line`). | `docs/SOP_Sale_Revenue_Account_Per_Line_Note_2026-10-18.md` |
| FR-SOP-FEE-05 | The caller prices a service line (price bounds enforced; item ids must be UUIDs); the line currency must equal the Company's (`FR-SOP-CUR-01`). | **Built** | S1 |
| FR-SOP-FEE-06 | A fee invoice carries the customer reference and service period (quantity decimal to 4 places). | **Built** | `docs/SOP_Decimal_Quantity_And_Customer_Reference_SPUTO.md` UC-1..9 |
| FR-SOP-FEE-07 | The sale is claim-first idempotent on the caller's `Idempotency-Key`: a retry after a timeout posts once. | **Built** | `respondIdempotently`; `RT3-FEE1` |
| FR-SOP-FEE-08 | Billing accounts, term billing runs, per-school receipts, waivers/refunds, inbox/outbox: see `FR-SOPFEE-04..23`. | **Not built, Not in MVP of this path** | `docs/Fee_Billing_Epic13_SOP_Half.md` |

**UC-SOP-FEE-1 ER raises one fee invoice.** Main: ER calls `POST /api/sales` with a customer, one service item line, its price, and a key. SOP checks the credential and the Company, reads the item from IM (service, VAT category), checks the currency, posts the sale to GL, stores the order. Answer: the invoice with its number.
**UC-SOP-FEE-2 A service item with no VAT category.** Refused 409 `item_has_no_vat_category` naming the item; nothing saved or posted; the school asks its Owner Admin to set the category in Inventory (UC-TJ-5).
**UC-SOP-FEE-3 ER asks for something its credential may not do.** A stock item, a cash sale, a Company not on the school list: refused 403; nothing is created.
**UC-SOP-FEE-4 A timeout then a retry.** The same key and body replays the stored answer or finishes the open claim; one invoice exists.

## 3. Accounts receivable: `FR-SOP-AR` (SOP owns the receivables sub-ledger; GL aggregates; CM/Femi 2026-10-18)

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-SOP-AR-01 | Every collection is a **receipt** (amount, date, settlement account, ledger entry id) inside the sale; `openAmount = gross - collected - credited`. | **Built** | receipts and credit application (master `618150c`, PR #42); `docs/SOP_AR_Receipts_And_Credit_Application_Design_2026-10-18.md` |
| FR-SOP-AR-02 | An overpayment is allowed in principle (Femi 2026-10-18): the excess is held as its own record, a credit balance owed to the customer. | **Built** as the record; **Not built**: posting the excess to GL's "Overpayments on Invoice" account. GL's design (GL review): an optional `overpaymentAccountId` on the sales posting context, null until configured, so SOP can feature-detect; waits for Femi's approval of the account. **Interim (stays right):** a collection above what is open is refused `409 overpayment_posting_not_available` behind the default-off switch `SOP_OVERPAYMENT_POSTING_ENABLED`. | |
| FR-SOP-AR-03 | A credit note is applied to its sale, once (unique per credit note), same currency only; it may exceed the open amount (a credit balance, Femi 2026-10-18) but never the invoice's gross. | **Built** | PR #42 |
| FR-SOP-AR-04 | A sale whose collected total was written by an older task, with no receipt, keeps its money as one legacy receipt (stable id). | **Built** | V20 backfill; `ReceiptsMigrationIntegrationTest` |
| FR-SOP-AR-05 | A reconciler applies credit notes that were issued but not applied, every 15 minutes (jittered), reporting a refused note once per process. | **Built** | `CreditApplicationReconciler` |
| FR-SOP-AR-06 | A cancelled sale owes nothing. | **Built** | |
| FR-SOP-AR-07 | Status meaning: `COLLECTED` = nothing left to collect (open <= 0); `PARTIALLY_COLLECTED` = something received or credited and an amount open; `INVOICED` = untouched. | **Unclear: an assumption awaiting Femi** (a fully credited, never-paid sale shows `COLLECTED`) | design note section 3, rule 3 |
| FR-SOP-AR-08 | A sale has its **own date** (the invoice date), distinct from when it was recorded; ageing and overdue run from it; existing sales take their creation day. | **Built** | `d084d45` (V21), master |
| FR-SOP-AR-09 | The system can read what was owed at any past date: receipts and credits dated after that date are ignored; a sale not yet invoiced then is not owed. | **Built** | `d084d45` |
| FR-SOP-AR-10 | An ageing summary read for EA: currency, as-of, total outstanding, overdue total and count, overdue basis, undated amount, credit balance total; `409 multiple_currencies` when open sales are in more than one currency. | **Built** | PR #43 (master `344a972`); contract fixtures `sop/receivables-ageing-summary*.json` |
| FR-SOP-AR-11 | Overdue runs from the **due date** once credit terms exist (today: invoice date + 30 days, `INVOICE_DATE_30`). | **Not built** (waits POP's shared terms fixture) | |
| FR-SOP-AR-12 | One sale's money acts (collect, credit-note apply) are serial: a per-sale lock; a busy sale answers `409 order_busy`; the lock survives a lost connection or a cancelled request. | **Built** | `OrderLock`, `PostgresAdvisoryOrderLock`; `OrderConcurrencyIntegrationTest`, `PostgresAdvisoryOrderLockIntegrationTest` |
| FR-SOP-AR-13 | Collections and credit-note postings are idempotent end to end: derived GL keys (`collect:`, `credit-note:{returnRequestId}`), a retry finishes rather than doubles. **A collection must carry a client `Idempotency-Key`; without one it is refused `400 idempotency_key_required` before anything is posted** (a lost answer would otherwise let a retry post the cash twice, and SOP could not recognise it). | **Built** (key requirement: branch `feature/collection-requires-idempotency-key`) | `IssueCreditNoteUseCaseTest` |
| FR-SOP-AR-14 | A payment method maps to a per-Company settlement account, validated against GL's list (never a silent fallback), and every payment gets a numbered receipt (`RCT-000001`), voided not deleted. | **Not built** in SOP (design: `docs/SOP_Payment_Method_And_Receipt_Number_Note_2026-10-18.md`). **GL's half is deployed** (GL review): `settlementAccounts` on the sales posting context and an optional `reference` on record-collection, so SOP can validate the settlement account now. GL has no record-sale/record-collection response fixtures yet; SOP asks GL to write them. Today any GL account id is passed through and GL decides. | |
| FR-SOP-AR-15 | A Bill for Collection collection also records a receipt on the sale. | **Not built** | |
| FR-SOP-AR-16 | A posting GL holds that SOP never recorded is found and finished. | **Not built.** GL has no read by key and recommends **replaying the same request with the same key** (GL returns the original posting) instead of adding a read, unless SOP shows a case replay cannot cover. | GL review |
| FR-SOP-AR-17 | A credit note records when it was issued. | **Not built** | |
| FR-SOP-AR-18 | Child rows are loaded in batches, not one query per sale: a list of sales costs one query per child table whatever the number of sales. | **Built** (branch `feature/batch-sales-order-child-rows`; integration tests: statement count 31 to 6 for six sales, and list-equals-single-read) | |
| FR-SOP-AR-19 | Third-party payments and Discounts Given. | **Not in MVP**: awaiting Femi's answers on the design note. | `docs/SOP_Third_Party_Payments_And_Discounts_Given.md` |
| FR-SOP-AR-21 | A sale (`POST /api/sales`, credit or cash) must carry a client `Idempotency-Key`; without one it is refused `400 idempotency_key_required` before anything is read, issued or posted (a lost answer would otherwise let a retry create a second sale, and for a cash sale a second receipt, unrecognisable to SOP). Same rule, same code as FR-SOP-AR-13. | **Not built** (CM go 2026-10-22; next change) | |
| FR-SOP-AR-22 | A Bill for Collection collection (`POST /api/bills-for-collection/{id}/collect`) must carry a client `Idempotency-Key`, is claimed claim-first like a collection, and forwards a derived key to GL so a retry after a crash between GL and SOP's save replays instead of posting the cash twice. | **Not built** (CM go 2026-10-22). **Unclear, flagged to CM, not changed here:** the use case deliberately persists the Bill as COLLECTED even when GL fails (`CollectBillForCollectionUseCaseTest`, "still persists the domain-side collection"), so a retry after a GL failure answers `409 bill_not_ready_to_collect` and the cash is never posted; that eventual-consistency trade-off was an accepted design choice and needs Femi's say before it changes. | |
| FR-SOP-AR-20 | SOP's open receivables total equals GL's receivables control balance (account 1100) as at the same date; a difference is reported, not enforced. | **Not built** (added at GL's review) | GL review |

**UC-SOP-AR-1 Collect part payment.** Main: a person records 40 of a 100 invoice. A receipt is added, the sale is `PARTIALLY_COLLECTED`, open 60. Err: the sale is busy, the ledger refuses, or the key is replayed: see AR-12/13.
**UC-SOP-AR-2 Collect more than is open.** Main (today): refused `overpayment_posting_not_available`; nothing posted. Main (when GL can hold it): the excess becomes an overpayment, shown as a credit balance.
**UC-SOP-AR-3 Goods come back after payment.** A credit note larger than the open amount makes the open amount negative: a credit balance owed to the customer, shown separately in ageing, never netted into a bucket.
**UC-SOP-AR-4 The dashboard reads ageing.** EA asks SOP for the summary; SOP answers in the Company's single currency, or `409 multiple_currencies`.
**UC-SOP-AR-5 What was owed on a past date.** The summary with an earlier `asOf` ignores later receipts and credits and omits sales invoiced after it.
**UC-SOP-AR-6 A backdated invoice.** A sale entered today but dated 30 days ago is aged from its own date, not from today.
**UC-SOP-AR-7 Two people collect on the same sale at once.** One proceeds; the other gets `order_busy` and retries; the total is exact.
**UC-SOP-AR-11 Retry a sale after a lost answer.** Main: the screen sends the identical sale with the same key: the stored answer replays (or GL replays its posting); one sale, and for a cash sale one receipt, exists. Err: a sale sent with no key is refused 400 `idempotency_key_required`; nothing is created.
**UC-SOP-AR-12 Retry a Bill for Collection collection.** Main: the same collection with the same key replays; GL holds one posting. Err: no key is refused 400 `idempotency_key_required`.
**UC-SOP-AR-10 Retry a collection after a lost answer.** Main: the screen lost the answer and sends the identical collection with the same key: the stored answer replays, or GL replays its original posting; one receipt exists. Err: a collection sent with no key is refused 400 `idempotency_key_required`; nothing is posted.
**UC-SOP-AR-9 SOP and the ledger disagree.** Main: for a date, SOP's open total (FR-SOP-AR-20) is compared with GL's 1100 balance; a difference is shown with both figures and is not corrected by SOP (reported, not enforced).
**UC-SOP-AR-8 A credit note is issued and the apply step is lost.** The reconciler applies it within 15 minutes; applying twice is impossible.

## 4. What delivered work cites (for CM's gate; the IDs above must be approved first)

| Delivered | Cites |
|---|---|
| `64ceaf3` company-currency refusal (+ fixture `aa579a6`) | FR-SOP-CUR-01..04, UC-SOP-CUR-1..3; UC-TJ-15, TJ-CUR-10, TJ-CUR-6, T-TJ-27 (UC-TJ-4 as screen counterpart) |
| `ac54dc9` S1 fee invoice | FR-SOP-FEE-01..03, 05..07, UC-SOP-FEE-1..4 (FR-SOPFEE-03/11 in part; RT3-FEE1) |
| `d084d45` invoice date and true as-of | FR-SOP-AR-08, 09; UC-SOP-AR-5, 6 |
| PR #42 receipts and credit application | FR-SOP-AR-01..06, 12, 13; UC-SOP-AR-1..3, 7, 8 |
| PR #43 ageing summary | FR-SOP-AR-10; UC-SOP-AR-4 |

## 5. Decisions needed from Femi

1. *(Not Femi's: parked as `PQ-22` in the Tax playbook; CM can settle it. SOP stays at 400.)*
2. **Status meaning** (`FR-SOP-AR-07`): confirm `COLLECTED` = nothing left to collect.
3. **Overpayment posting** (`FR-SOP-AR-02`): approve GL's "Overpayments on Invoice" account so the interim refusal can go.
4. **MVP line:** confirm `FR-SOP-AR-14..18` (numbered receipts, Bill receipt, detector, issue time, batching) and `FR-SOP-FEE-04` are in the first cohort, or parked.

## 6. Sources

`docs/SOP_AR_Receipts_And_Credit_Application_Design_2026-10-18.md`, `docs/SOP_Accounts_Receivable_Completeness_Assessment_2026-10-18.md`, `docs/SOP_Payment_Method_And_Receipt_Number_Note_2026-10-18.md`, `docs/SOP_School_Fee_Invoices_Needs_2026-10-18.md`, `docs/SOP_Sale_Revenue_Account_Per_Line_Note_2026-10-18.md`, `docs/SOP_Generic_Core_And_Runtimes_SPUTO.md`, `docs/Fee_Billing_Epic13_SOP_Half.md`, `docs/Tax_And_Currency_Jurisdictions_Playbook.md`, `docs/Decisions_Log.md` (2026-10-18 AR decisions, 2026-10-22 currency and traceability entries), `Retest_Plan_2026-10-18.md` in the Reviewer's TestPlans folder (RT3-FEE1; that file was not on master when this was written).
