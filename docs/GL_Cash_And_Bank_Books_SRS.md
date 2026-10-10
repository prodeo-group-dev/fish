# GL Cash and Bank Books: Software Requirements Specification (SPUTO: Scope and Plan)

**Status:** 2026-10-10, GL session. Requirements only; nothing is built. Priority: **urgent, high** (Femi, 2026-10-10). Companion documents: `docs/GL_Cash_And_Bank_Books_Use_Cases.md` (U), `docs/GL_Cash_And_Bank_Books_Backlog.md` (T and O). Code references are to GL master `6ea02f8`.

## 1. Introduction

### 1.1 The requirement (Femi, 2026-10-10)

> "You should have cash and bank accounts, of which bank accounts have a further feature of bank reconciliation, which also double as General Ledger accounts. They are books of original entry."

Read as five requirements: (1) a Company has **cash accounts** and **bank accounts**, as two kinds; (2) a **bank** account has a further feature that a cash account does not: **bank reconciliation**; (3) each is also an ordinary **General Ledger account**, so the trial balance, balance sheet and every report keep working from the same postings; (4) each is a **book of original entry**: entries are first recorded in it (a receipt, a payment), not only derived from other documents; (5) Femi's answer on layout: **one book per account** (no combined three-column book).

### 1.2 Scope (the problem, from the code)

What GL has today (verified):
- One cash account only: every chart template seeds `1000 Cash` (`ChartOfAccountsTemplate.CASH_CODE`). There is no Bank account in any template.
- `Account` has no field saying an account is a cash or bank account. It carries type, classification, code, name, parent, active flag and an expense classification.
- Bank reconciliation (`BankReconciliation`, V32) works on **any** account id of the Company. Nothing requires a bank account. It matches whole statement lines to whole posted entries and can tie out the balance (`enforceBalanceTieOut`, currently off).
- No cash book or per-account ledger exists. The nearest read is `GET /companies/{id}/journal-entries` (all entries, newest first, no account or date filter, no running balance).
- Cash and bank are never an original-entry point. All postings come from a generic journal, or from SOP/POP/IM/HR through the posting routes.
- Services hard-wire the cash account by code: SOP's cash sale (`CreateSalesInvoiceUseCase`, posting-context `cashAccountId`), the purchase and payroll posting contexts, and `ComputeCashFlowUseCase` all look up code `"1000"` and nothing else. **A Bank account added today would be invisible to the cash-flow statement and to every service's cash settlement.**
- POP supplier payments already take a `settlementAccountId` from the caller; HR's pay run takes `cashAccountId`; WEB's reconciliation screen offers all ASSET accounts.

**In scope:** the Account kind (cash/bank); seeding a Bank account in charts; per-account books (the report); recording receipts, payments and transfers in the books (original entry); making cash flow, services and reconciliation aware of the kind; backfill for existing Companies.
**Out of scope:** foreign-currency bank accounts (IAS 21 FX not built for this purpose); bank feeds/open banking (see `docs/External_Regulatory_And_Banking_API_Integrations_Requirements_Specification.md`); card/merchant fees; cash discounts (no discount columns); a combined multi-account book (Femi: one book per account); Period management (`docs/GL_Period_Management_Scoping.md`, separate).

### 1.3 Definitions

*Cash account*: an ASSET account of kind CASH (till, petty cash, imprest). *Bank account*: an ASSET account of kind BANK; the only kind that can be reconciled. *Book*: the chronological record of an account's postings with a running balance. *Book of original entry*: a book in which a transaction is first recorded, producing its journal posting as a consequence. *Counter-account*: the other side of a receipt or payment.

## 2. Overall description

- **Users:** Business Owner and accountants (record and read books, reconcile); non-accountants record "money in" and "money out" in plain words; services (SOP/POP/IM/HR) choose a cash or bank account when they settle.
- **Principle kept:** GL stays generic (Ledger knows no business type). The kind is a ledger concept (as an expense classification is), not a Purse or school concept.
- **Assumptions:** the Company's base currency is the only currency (Decision D3). Tenant and Company isolation exactly as every other route (T15). RBAC freeze: new routes use the existing `authorizeTenantFor{Read,Write}` levels, no new roles or permissions; new refusals only (see 7).

## 3. Decisions

| # | Decision | State |
|---|---|---|
| D1 | One book **per account**; no combined book. | **Femi, 2026-10-10** |
| D2 | Books are books of original entry: receipts, payments and transfers are recorded in the book and post the journal. | Femi's requirement; mechanics proposed here |
| D3 | Base currency only for now (reconciliation already refuses other currencies). | Proposed, confirm |
| D4 | Chart templates gain `1010 Bank` (BANK); `1000 Cash` becomes CASH. Free code in every template (checked: 1000, 1100, 1200, 1300 are the only codes in the 10xx-13xx range). | Proposed, confirm |
| D5 | Trade receipts and payments are **not** recorded through a book against module-owned control accounts (AR 1100, AP 2000, VAT 2150, Inventory 1300, Fixed Assets 1200/1210, Opening-balance equity 3900, Suspense 3910); they go through SOP collection / POP payment so AR/AP stay itemised. The cash book refuses them with a message naming the right screen. | Proposed, confirm |
| D6 | New `JournalSource.CASH_BOOK` for entries from the books, so the audit trail shows original entry. Falls back to `MANUAL` if a consumer cannot take a new value (T-check in backlog). | Proposed |
| D7 | Bank reconciliation only on BANK accounts, introduced log-first (as G3 was), then enforced. | Proposed |
| D8 | A payment that takes a CASH account below zero is allowed but returns a warning; a BANK account below zero is an overdraft and is presented as a liability by the existing `TrialBalance` overdraft reclass. | Proposed |

## 4. Functional requirements (MoSCoW)

**Account kind**
- **FR-CB01 (M)** An `Account` of type ASSET may carry `cashBookKind` = `CASH` or `BANK`; any other type may not (domain invariant, tested). Other accounts have none.
- **FR-CB02 (M)** The kind is set when the account is created (`POST /companies/{id}/accounts` gains optional `cashBookKind`) and can be changed by `PUT /companies/{id}/accounts/{accountId}/cash-book-kind` (same shape as `expense-classification`). BANK cannot be cleared while a reconciliation exists for the account.
- **FR-CB03 (M)** `GET .../accounts` returns `cashBookKind` (additive, nullable field).
- **FR-CB04 (M)** Every chart template seeds `1000 Cash` (CASH) and `1010 Bank` (BANK), both CURRENT.
- **FR-CB05 (M)** Existing accounts coded `1000` of type ASSET are backfilled to CASH by migration. No account is auto-flagged BANK.
- **FR-CB06 (M)** An owner can create further cash and bank accounts (several bank accounts, petty cash) with ordinary account creation.

**The book (read)**
- **FR-CB10 (M)** `GET /companies/{id}/cash-books/{accountId}?from=&to=` returns the account's book: opening balance at `from`, rows in date order (date, entry id, description, source, counter-account(s), money in = debit, money out = credit, running balance), totals, closing balance. Only POSTED entries (those with historical effect, the predicate reconciliation uses) appear; a reversal appears as its own row, flagged `reversalOf`.
- **FR-CB11 (M)** The book is available only for accounts with a `cashBookKind`; otherwise 409 `not_a_cash_or_bank_account`. Unknown or other-Company account: 404 (never confirms another Company's account).
- **FR-CB12 (M)** `GET /companies/{id}/cash-books` lists the Company's cash and bank accounts with kind and current balance (the landing view).
- **FR-CB13 (S)** Date defaults: this month to date when `from`/`to` are absent; a range over 5,000 rows is refused with `range_too_large` (the client narrows or pages).
- **FR-CB14 (S)** Each row carries `reconciled` for BANK accounts (matched in a COMPLETED reconciliation) so the book shows what is cleared.

**Original entry (write)**
- **FR-CB20 (M)** `POST /companies/{id}/cash-books/{accountId}/receipts` records money in: date, amount, counter-account, description, optional reference. Posts a balanced two-line entry: debit the book account, credit the counter-account. Source `CASH_BOOK` (D6).
- **FR-CB21 (M)** `POST .../payments` records money out: debit the counter-account, credit the book account.
- **FR-CB22 (M)** Counter-account rules: belongs to the same Company, is not the book account, is active, and is not a module-owned control account (D5). Violations are named errors (`counter_account_not_allowed`, with which screen to use).
- **FR-CB23 (M)** Every entry route honours the `Idempotency-Key` mechanism GL already has (a money-posting foundation, per Femi's order of work: guards before features).
- **FR-CB24 (S)** `POST .../transfers` moves money between two cash/bank accounts of the Company (cash to bank, bank to bank): one entry, appears in both books.
- **FR-CB25 (S)** A payment taking a CASH account below zero succeeds with `warnings: ["cash_below_zero"]` (D8).
- **FR-CB26 (M)** A wrong entry is corrected by reversal (existing `ReverseJournalEntryUseCase`), never by edit; the book shows both rows.
- **FR-CB27 (C)** Optional dimensions on a receipt/payment (customer, supplier, employee) where the counter-account is not a control account; deferred.

**Bank reconciliation**
- **FR-CB30 (M)** Starting a reconciliation requires a BANK account (D7, log-first, then enforce). Existing reconciliations are unaffected.
- **FR-CB31 (S)** The reconciliation screen's account list is BANK accounts only.

**Cash flow and reports**
- **FR-CB40 (M)** The statement of cash flows treats all CASH and BANK accounts as "cash and cash equivalents" (IAS 7): opening, closing and net cash flow sum across them; **transfers between them are not cash flows**. For a Company with only `1000`, output is identical to today (regression-tested).
- **FR-CB41 (M)** Trial balance, balance sheet and working capital are unchanged by this work (the accounts are ordinary ASSET accounts).
- **FR-CB42 (S)** BANK accounts with a negative balance flow through the existing overdraft presentation (D8).

**Services (cross-service, additive)**
- **FR-CB50 (M)** The sales, purchase and payroll posting contexts return, additively, `cashAndBankAccounts: [{accountId, code, name, kind}]`. The existing `cashAccountId` stays (the `1000` account) so no consumer breaks.
- **FR-CB51 (S)** SOP's cash-sale and collection, POP's payment and HR's pay run each let the caller choose the cash or bank account to settle into. GL already accepts any account id; the change is in the consumers' requests and WEB.
- **FR-CB52 (S)** Settlement accounts must be cash/bank accounts of the Company (D7-style, log-first, then enforce) so a payment cannot be settled into an arbitrary account.

**Existing Companies**
- **FR-CB60 (M)** A use case adds missing template accounts to an existing Company, idempotently and reporting what it added or skipped (a code already used by a different account is skipped and reported, never overwritten): `1010 Bank` and also the VAT control account `2150` (the same fix queued after the Period scoping). No unique constraint on `(company_id, code)` exists, so the use case checks in code.
- **FR-CB61 (S)** WEB offers "Add a bank account" when a Company has none, using ordinary account creation with the BANK kind, so no mass backfill is needed for the first owners.

**Opening figures**
- **FR-CB70 (S)** A cash or bank account's opening balance uses the existing opening-balance route (`POST .../accounts/{id}/opening-balance`), and the book's opening row shows it.

## 5. Non-functional requirements

- **NFR-CB01 Isolation.** Every route is Company-scoped through `resolveTenantForCompany` and `verifyClaimedTenant`; the account must belong to the Company (guess-the-id test, 404). The T15 route-inventory test must classify the new routes (people-only; none are on a service allow-list) and the isolation matrix covers them.
- **NFR-CB02 Correctness.** The book's running balance equals the account's ledger balance as the trial balance computes it, to the cent, in a property test; the closing balance of a range equals opening of the next.
- **NFR-CB03 No second door.** All entries go through `PostJournalEntryUseCase`; a source-scan test forbids a cash-book route writing journal entries any other way.
- **NFR-CB04 Performance.** A book for one account over a month reads through `journal_lines(account_id)` (index exists, V2) and does not load the whole Company's entries; add a repository method for it.
- **NFR-CB05 Concurrency.** Two simultaneous receipts to one account both post and the running balance stays consistent (idempotency key plus ordering by entry date then creation).
- **NFR-CB06 Audit.** Entries carry the actor, `CASH_BOOK` source and reference; reversals link to the original.
- **NFR-CB07 Additive contracts.** Every response change is a new nullable field; consumers are told first (consumers-first), EA's strict decoders are checked for any response it reads (journal-entries is not one of them).
- **NFR-CB08 Plain language.** WEB labels read "Money in" and "Money out", not debit and credit; no accounting terms on the first screen.

## 6. Data requirements

- Migration (next free number after V32; coordinate with the Period and fixed-asset-link work, both of which also want a migration): `accounts.cash_book_kind VARCHAR(10) NULL CHECK (cash_book_kind IN ('CASH','BANK'))`; backfill `UPDATE accounts SET cash_book_kind='CASH' WHERE code='1000' AND type='ASSET'`.
- `JournalSource` gains `CASH_BOOK`; `journal_entries.source` is `VARCHAR(20)`, no schema change.
- Read model: a repository method returning the posted lines of one account between two dates with their entry headers (uses `idx_journal_lines_account_id`).

## 7. External interfaces and constraints

- **GL HTTP:** new routes (FR-CB10..CB12, CB20, CB21, CB24, CB02); new field on `GET accounts` and on the three posting contexts. Authorization: READ for books, WRITE for entries and kind changes; Owner-Admin has both at every Company of the business.
- **RBAC freeze:** nothing here adds a permission; the refusals added later (D7, FR-CB52) are add-a-deny only.
- **Services:** SOP, POP, HR change only to let the caller pick the account (FR-CB51); IM unaffected. **WEB:** a Cash and Bank section (list, book, money in/out forms, transfer, reconcile for BANK, "add a bank account"), and account pickers on the SOP cash sale, POP payment and HR pay run screens. WEB owns the design and the section-7 layout checklist.
- **EA dashboard:** any cash tile reads figures that do not change; shapes are unchanged.

## 8. Risks and open issues

1. **Cash flow** reads only `1000` today: if a Bank account is created before FR-CB40 ships, the cash-flow statement silently omits it. So FR-CB40 must ship **with or before** the first Bank account is created (backlog order enforces it; the Bank template seed is the last step of Release A, not the first).
2. **`JournalSource.CASH_BOOK`:** a strict consumer decoding the enum would fail; T-check before the value is used.
3. **Module-owned control account list (D5)** is by code today; a Company that renamed or re-coded them could slip a counter-account through. Identify them by the same resolvers the posting contexts use, not by code literals.
4. **Reconciliation grandfathering:** a Company that reconciles `1000 Cash` today must be able to flag it BANK before D7 enforces (FR-CB02 allows CASH to BANK).
5. **Period interaction:** entries use the open-Period lookup the other posting routes use; when Period management lands, the books adopt its resolver with no change here.
6. **Unconfirmed decisions:** D2 mechanics, D3 to D8 need Femi's confirmation before the dependent tasks start.
