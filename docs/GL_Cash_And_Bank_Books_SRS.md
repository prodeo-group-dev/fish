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
- **Correction (found while starting the build, 2026-10-10):** a domain command for exactly this already exists, `CashBookEntry` (`domain/ledger/cash_book_entry.kt`, built 2026-08-12 as the original Ledger feature, with `CashDirection` RECEIVED/PAID, an IAS 7 `cashFlowActivity` tag defaulting to OPERATING, and `toJournalEntry()`). It was never wired: no use case, route, persistence or screen exposes it, and it posts with `JournalSource.MANUAL` (its KDoc says a new enum value was "not worth it"; Femi's confirmed D6 now overrides that with `CASH_BOOK`). So cash and bank are books of original entry in the **domain** but not in the product. Release B reuses `CashBookEntry` rather than inventing a new command. All other postings come from a generic journal, or from SOP/POP/IM/HR through the posting routes.
- Services hard-wire the cash account by code: SOP's cash sale (`CreateSalesInvoiceUseCase`, posting-context `cashAccountId`), the purchase and payroll posting contexts, and `ComputeCashFlowUseCase` all look up code `"1000"` and nothing else. **A Bank account added today would be invisible to the cash-flow statement and to every service's cash settlement.**
- POP supplier payments already take a `settlementAccountId` from the caller; HR's pay run takes `cashAccountId`; WEB's reconciliation screen offers all ASSET accounts.

**In scope:** the Account kind (cash/bank); seeding a Bank account in charts; per-account books (the report); recording receipts, payments and transfers in the books (original entry); making cash flow, services and reconciliation aware of the kind; backfill for existing Companies.
**Out of scope:** foreign-currency bank accounts (IAS 21 FX not built for this purpose); bank feeds/open banking (see `docs/External_Regulatory_And_Banking_API_Integrations_Requirements_Specification.md`); card/merchant fees; cash discounts (no discount columns); a combined multi-account book (Femi: one book per account); Period management (`docs/GL_Period_Management_Scoping.md`, separate).

### 1.3 Definitions

*Cash account*: an ASSET account of kind CASH (till, petty cash, imprest). *Bank account*: an ASSET account of kind BANK; the only kind that can be reconciled. *Book*: the chronological record of an account's postings with a running balance. *Book of original entry*: a book in which a transaction is first recorded, producing its journal posting as a consequence. *Counter-account*: the other side of a receipt or payment.

## 2. Overall description

- **Users:** Business Owner and accountants (record and read books, reconcile); non-accountants record "money in" and "money out" in plain words; services (SOP/POP/IM/HR) choose a cash or bank account when they settle.
- **Account `1000`:** is where the services default to (SOP cash sale, POP payment, HR pay run use it today), so it remains the default settlement account. It is always the Cash Book (D4); the owner's bank accounts are further cash books and are chosen explicitly.
- **Principle kept:** GL stays generic (Ledger knows no business type). The kind is a ledger concept (as an expense classification is), not a Purse or school concept.
- **Assumptions:** the Company's base currency is the only currency (Decision D3). Tenant and Company isolation exactly as every other route (T15). RBAC freeze: new routes use the existing `authorizeTenantFor{Read,Write}` levels, no new roles or permissions; new refusals only (see 7).

## 3. Decisions

| # | Decision | State |
|---|---|---|
| D1 | One book **per account**; no combined book. | **Femi, 2026-10-10** |
| D2 | Books are books of original entry: receipts, payments and transfers are recorded in the book and post the journal. | Femi's requirement; mechanics proposed here |
| D3 | **The Company's primary cash and bank currency is the currency of its tax jurisdiction, determined and seeded when the Company is created** (Femi, 2026-10-10: "every company has its tax jurisdiction; the currency in which that tax jurisdiction operates is the primary cash and bank account currency"). The currency is reference data on `jurisdictions` (new `currency` column), not a free choice at creation. **Later in the same day Femi extended this: a Company may open other cash/bank accounts in other currencies.** That is phased (section 9): **Phase 1 is primary-currency books only, and no foreign-currency account is built until an IAS 21 design exists.** | Femi's rule confirmed; extension phased; currency mapping for LR, GN, CI open (section 8, item 7) |
| D4 | **Account `1000` is the Cash Book in every country, and bank accounts are further cash books created as needed** (Femi, 2026-10-10: "A Cash Book is account 1000 and further cash books that have the feature of Bank reconciliation can be created as needed, i.e. Bank Accounts. They are all books of original entry"). No kind split by jurisdiction. Every chart template seeds `1000 Cash` with kind CASH; a bank account is a further account created by the owner (default code the next free `10xx` from `1010`), kind BANK, reconcilable. A Bank account is **not** seeded for every Company. Account `1000` stays CASH and its kind cannot be changed. A mobile-money wallet (Orange Money, MTN MoMo) "is just another bank account in our own books": a BANK cash book like any other, created as needed; there is no third kind. | **Femi, 2026-10-10** |
| D5 | Trade receipts and payments are **not** recorded through a book against module-owned control accounts (AR 1100, AP 2000, VAT 2150, Inventory 1300, Fixed Assets 1200/1210, Opening-balance equity 3900, Suspense 3910); they go through SOP collection / POP payment so AR/AP stay itemised. The cash book refuses them with a message naming the right screen. | Proposed, confirm |
| D6 | New `JournalSource.CASH_BOOK` for entries from the books, so the audit trail shows original entry. Falls back to `MANUAL` if a consumer cannot take a new value (T-check in backlog). | Proposed |
| D7 | Bank reconciliation only on BANK accounts, introduced log-first (as G3 was), then enforced. | Proposed |
| D8 | A payment that takes a CASH account below zero is allowed but returns a warning; a BANK account below zero is an overdraft and is presented as a liability by the existing `TrialBalance` overdraft reclass. | Proposed |

## 4. Functional requirements (MoSCoW)

**Account kind**
- **FR-CB01 (M)** An `Account` of type ASSET may carry `cashBookKind` = `CASH` or `BANK`; any other type may not (domain invariant, tested). Other accounts have none.
- **FR-CB02 (M)** The kind is set when the account is created (`POST /companies/{id}/accounts` gains optional `cashBookKind`) and can be changed by `PUT /companies/{id}/accounts/{accountId}/cash-book-kind` (same shape as `expense-classification`), except on account `1000` (FR-CB06). BANK cannot be cleared or changed to CASH while a reconciliation exists for the account.
- **FR-CB03 (M)** `GET .../accounts` returns `cashBookKind` (additive, nullable field).
- **FR-CB04 (M)** Every chart template seeds `1000 Cash` as a CURRENT ASSET account with kind CASH (D4). No Bank account is seeded. A Company's currency, and therefore the currency of `1000`, is seeded at creation from its jurisdiction (FR-CB07).
- **FR-CB05 (M)** Existing accounts coded `1000` of type ASSET are backfilled to CASH by migration, for every Company, regardless of jurisdiction. No other account is auto-flagged. Existing reconciliations against `1000` stay readable (section 8, item 4).
- **FR-CB06 (M)** An owner can create further cash books and bank accounts (several bank accounts, a mobile-money wallet as BANK, petty cash as CASH) with ordinary account creation, in the Company's currency. Account `1000`'s kind cannot be changed (409 `prime_cash_book_kind_fixed`).
- **FR-CB07 (M)** The Company's base currency is derived from its jurisdiction at creation (D3): `AddCompanyToTenantUseCase` reads `jurisdictions.currency`. The `companyBaseCurrency` field of the create-Company request becomes optional; if sent it must equal the jurisdiction's currency, otherwise 409 `currency_not_supported_for_jurisdiction`. Existing Companies keep their stored currency.

**The book (read)**
- **FR-CB10 (M)** `GET /companies/{id}/cash-books/{accountId}?from=&to=` returns the account's book: opening balance at `from`, rows in date order (date, entry id, description, source, counter-account(s), money in = debit, money out = credit, running balance), totals, closing balance. Only POSTED entries (those with historical effect, the predicate reconciliation uses) appear; a reversal appears as its own row, flagged `reversalOf`.
- **FR-CB11 (M)** The book is available only for accounts with a `cashBookKind`; otherwise 409 `not_a_cash_or_bank_account`. Unknown or other-Company account: 404 (never confirms another Company's account).
- **FR-CB12 (M)** `GET /companies/{id}/cash-books` lists the Company's cash and bank accounts with kind and current balance (the landing view).
- **FR-CB13 (S)** Date defaults: this month to date when `from`/`to` are absent; a range over 5,000 rows is refused with `range_too_large` (the client narrows or pages).
- **FR-CB14 (S)** Each row carries `reconciled` for BANK accounts (matched in a COMPLETED reconciliation) so the book shows what is cleared.

**Original entry (write)**
- **FR-CB20 (M)** `POST /companies/{id}/cash-books/{accountId}/receipts` records money in: date, amount, counter-account, description, optional reference. Built on the existing `CashBookEntry` (optional `cashFlowActivity`, default OPERATING, so IAS 7 categorisation is explicit and not only inferred). Posts a balanced two-line entry: debit the book account, credit the counter-account. Source `CASH_BOOK` (D6).
- **FR-CB21 (M)** `POST .../payments` records money out: debit the counter-account, credit the book account.
- **FR-CB22 (M)** Counter-account rules: belongs to the same Company, is not the book account, is active, and is not a module-owned control account (D5). Violations are named errors: 409 `counter_account_not_allowed` carrying a `useInstead` token (SALES_COLLECTION, PURCHASE_PAYMENT, INVENTORY, FIXED_ASSETS, VAT, OPENING_FIGURES, TRANSFER), 404 `counter_account_not_found` for another Company's account, 409 `counter_account_inactive`. One list (`ModuleOwnedAccounts`) feeds both the refusal and the counter-account picker route, so a screen never offers what would be refused. **Built.**
- **FR-CB23 (M)** Idempotency on every entry route (receipts, payments, transfers): the `Idempotency-Key` header is required (400 `idempotency_key_required`). **As built (differs from the shared `respondIdempotently` helper):** the entry id is derived from tenant, company, book, direction and key, and the entry is stored only if no entry has that id (`JournalEntryRepository.insertIfAbsent`, first writer wins). A retry replays the same entry (201, `replayed: true`); the same key with a different request is 422 `idempotency_key_reused`; a refused request stores nothing, so its key is not spent; simultaneous identical requests post once, decided by the database. **Built.**
- **FR-CB24 (S)** `POST .../transfers` moves money between two cash/bank accounts of the Company (cash to bank, bank to bank): one entry, appears in both books.
- **FR-CB25 (S)** A payment taking a CASH account below zero succeeds with `warnings: ["cash_below_zero"]` (D8).
- **FR-CB26 (M)** A wrong entry is corrected by Undo, a reversing entry, never an edit; the book shows both rows. **As built (after CM's HIGH review):** Undo, and the book's `canUndo`, apply only to entries made in a cash or bank book (source `CASH_BOOK`). A sales collection, a supplier payment, a pay run or a journal is refused with 409 `undo_elsewhere` and a token saying where to reverse it (SALES_COLLECTION, PURCHASE_PAYMENT, INVENTORY, FIXED_ASSETS, VAT, OPENING_FIGURES, PAYROLL, ORIGINAL_SCREEN), because its own module would otherwise still show it paid. The reversal and the original's REVERSED status are written in one transaction. Undo requires an open Period; a repeat Undo is 409 `already_undone`. **Built.**
- **FR-CB27 (C)** Optional dimensions on a receipt/payment (customer, supplier, employee) where the counter-account is not a control account; deferred.

**Bank reconciliation**
- **FR-CB30 (M)** Starting a reconciliation requires a BANK account (D7). **As built: log-first.** `FISH_BANK_RECONCILIATION_MODE` unset or anything but `enforce` only logs `WOULD REFUSE reconciliation_requires_bank_account service=... company=... account=... route=...` and changes nothing; `enforce` refuses with 409 `reconciliation_requires_bank_account`. Existing reconciliations are unaffected. Account `1000` is the Cash Book and is not reconcilable.
- **FR-CB31 (S)** The reconciliation screen's account list is BANK accounts only.

**Cash flow and reports**
- **FR-CB40 (M)** The statement of cash flows treats all CASH and BANK accounts as "cash and cash equivalents" (IAS 7): opening, closing and net cash flow sum across them; **transfers between them are not cash flows**. For a Company with only `1000`, output is identical to today (regression-tested).
- **FR-CB41 (M)** Trial balance, balance sheet and working capital are unchanged by this work (the accounts are ordinary ASSET accounts).
- **FR-CB42 (S)** BANK accounts with a negative balance flow through the existing overdraft presentation (D8).

**Services (cross-service, additive)**
- **FR-CB50 (dropped, 2026-10-10)** Originally: the posting contexts return `cashAndBankAccounts`. **Dropped:** SOP, POP, IM and HR decode GL's posting-context responses strictly, so the addition would have broken all four. WEB reads the list from GL's own `GET /companies/{id}/cash-books` instead, and the services' existing account fields carry the chosen account. The existing `cashAccountId` in the contexts is unchanged.
- **FR-CB51 (S)** SOP's cash sale and collection, POP's payment, HR's pay run and IM's stock settlements each let the caller choose the cash or bank account to settle into: WEB shows the choice from GL's cash-book list and sends the chosen account id in the request field each service already has (a new optional field where there is none). GL already accepts any account id; the service-side changes are theirs. The postings land as ordinary lines on the chosen account, so they appear in its book (source of the originating module) and reconcile through the same bank-reconciliation match as any entry.
- **FR-CB52 (S)** The settlement account of a sales collection (`POST /sales/record-collection`), supplier payment (`POST /purchasing/record-payment`), pay run (`POST /payroll/record-pay-run`) and leave payout (`POST /leave-accruals/{id}/utilize`) must be a cash or bank book of the Company. **As built: log-first.** `FISH_SETTLEMENT_ACCOUNT_MODE` unset or anything but `enforce` only logs `WOULD REFUSE settlement_account_not_a_cash_book service=... company=... account=... route=...` and changes nothing; `enforce` refuses with 409 `settlement_account_not_a_cash_book`, before any idempotency record is made. Not applied to IM: its contra account is legitimately a payable. An account that does not exist or belongs to another Company is not judged here; the use case refuses it as before.

**Existing Companies**
- **FR-CB60 (M)** A use case adds missing standard accounts to an existing Company, idempotently and reporting what it added or skipped (a code already used by a different account is skipped and reported, never overwritten): the VAT control account `2150` (the same fix queued after the Period scoping) and the kind CASH on `1000`. It does not add a Bank account (D4). No unique constraint on `(company_id, code)` exists, so the use case checks in code.
- **FR-CB61 (S)** WEB offers "Add a bank account" (and "Add a cash account") when the owner wants another book, using ordinary account creation with the kind, so Companies need no seeded second account.

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
4. **Reconciliation grandfathering:** a Company that reconciles `1000 Cash` today cannot flag it BANK (D4 fixes `1000` as CASH). Such a Company creates a bank account and moves its balance by a transfer; existing reconciliation records on `1000` stay readable. Whether any exist in production is not known to GL; a read-only count for CM or Femi before D7 is enforced: `select count(*) from bank_reconciliations br join accounts a on a.id = br.account_id where a.code = '1000'`.
5. **Period interaction:** entries use the open-Period lookup the other posting routes use; when Period management lands, the books adopt its resolver with no change here.
6. **Decision state:** D2 mechanics and D5 to D8 are confirmed by Femi (2026-10-10, via CM). D1, D3 and D4 are Femi's own words. Open: item 7 and the questions in section 9.7.
7. **Currency mapping (needs Femi).** The jurisdiction YAMLs give: UK GBP, IE EUR, NG NGN, SL SLE. For Liberia, Guinea and Cote d'Ivoire they record LRD, GNF and XOF as `onboarded: false`, with the standing decision (2026-08-22) that this system recognises only SLE across the Mano River operation. Proposed seed, following that decision: LR, GN, CI = SLE. If Femi's rule ("the currency in which that tax jurisdiction operates") should mean the native LRD, GNF, XOF, those currencies must first be onboarded (GNF and XOF are zero-decimal and would be `Money`'s first), a larger change this SRS does not make.
8. **Mobile money is closed.** A wallet is an ordinary BANK cash book (Femi, 2026-10-10); there is no wallet kind and nothing parked.

## 9. Foreign-currency accounts (Femi, 2026-10-10): scope extension, phased

Femi added: "A company can then open other cash/bank accounts denominated in other currencies as they wish." This reverses the earlier base-currency-only decision (D3). It is a real extension with a known dependency, so it is phased and **no foreign-currency account is built in Phase 1**.

### 9.1 What the code has today (verified on master)

- `Money` always carries a currency and refuses to combine two currencies. `Company.baseCurrency` is the one currency a Company reports in.
- `Account` has **no currency**. `JournalLine.amount` is a `Money`; `JournalEntry.validateLines` requires the lines **of each currency to balance on their own**, so an entry that mixes GBP and USD lines must balance in GBP and in USD separately. There is no stored base-currency equivalent and no rate on a line.
- Some IAS 21 pieces exist: an `FXRate` value (`domain/ledger/fx_rate.kt`) and `RecordFXRevaluationUseCase`, a period-end revaluation of a **foreign-currency receivable**, where the caller supplies the rate and the currently recorded home value and GL posts only the delta to a caller-named FX gain/loss account. Nothing stores an FX position, an account's currency, a rate table, or a realised-gain calculation.
- Bank reconciliation refuses any currency other than the Company's base currency (`CurrencyMismatch`).
- The trial balance, balance sheet, cash-flow statement, working capital and the new cash book all assume one currency (they build `Money` with the base currency and would throw on a foreign line).
- Standing decision (2026-08-22): only SLE is onboarded across the Mano River operation; LRD, GNF and XOF are reference only. GBP, EUR and NGN are named in the jurisdiction YAMLs; USD is named in the spec's v1 currency list.

### 9.2 What an account currency means

Proposal: each cash and bank account carries its own `currency` (an ISO code). For `1000`, and for every account the owner opens without choosing, it is the Company's primary currency from its jurisdiction (D3). A foreign-currency account holds its balance in its own currency; the Company still reports in its base currency, so every report needs a translation rule (9.4).

### 9.3 How a foreign receipt, payment or transfer posts (the design choice)

Two shapes are possible, and the choice is architectural, so it is for the IAS 21 design pass and not made here:
- **A. Dual-amount lines.** A line keeps its amount in the account's currency and gains a stored base-currency equivalent and the rate used. Reports sum the base equivalent. Cleanest for reporting; changes `JournalLine` and every consumer that reads lines.
- **B. Per-currency clearing pairs.** Use only the existing per-currency balancing: debit the USD bank and credit an FX clearing account in USD; debit the FX clearing account in GBP and credit sales in GBP. No change to lines, but the clearing account's two currency balances must be revalued, and reports need a translation layer anyway.

**Rate source and who enters it** (Femi's call): a rate typed by the person at entry (simple, auditable, but error-prone for non-accountants), or a daily rate table GL keeps and offers as the default, with a manual override. A transfer between a base-currency and a foreign account needs the rate and the amount on **both** sides; the difference to the rate on the books is the realised gain or loss.

**Realised and unrealised.** A realised FX gain or loss arises when a foreign balance is spent or converted at a rate different from the rate it was booked at. An unrealised gain or loss arises at period end on the open foreign balance, revalued at the closing rate (IAS 21.23 and .28). Both need FX gain and loss accounts in the chart (today `RecordFXRevaluationUseCase` takes a caller-named account and the templates seed none), and the unrealised one needs a revaluation run per foreign cash/bank account per period, extending the existing use case from receivables to bank balances.

### 9.4 Reporting currency

The books report in the Company's base currency. Each foreign account shows two figures in its book: its own currency (the real balance) and the base-currency equivalent (at the book rate for the running balance, and at the closing rate for the period-end figure). The trial balance and balance sheet translate foreign accounts at the closing rate, with the revaluation difference in FX gain/loss. The cash-flow statement (IAS 7) translates foreign cash flows at the rate on the date, with the effect of exchange-rate changes on cash shown as its own line (IAS 7.28). None of this exists.

### 9.5 Reconciling a foreign account

A bank statement for a USD account is in USD. Reconciliation must compare the statement and the account in the **account's** currency, so `CurrencyMismatch` becomes "statement currency must equal the account's currency", the tie-out compares account-currency balances, and matching is by account-currency amounts. Realised FX differences on matched lines post as a separate adjustment, not inside the match.

### 9.6 Phasing and sizes

| Phase | Contents | Size (GL, rough) |
|---|---|---|
| **1: primary-currency books** (this SPUTO as drafted; the first slice already started) | Account kind, books, cash-flow fix, entries, reconciliation, all in the Company's one currency. The Company's currency comes from its jurisdiction. No account currency field. | as in the backlog, about 13.75 days |
| **2a: IAS 21 design** | Decide A or B, rate source, FX accounts, translation rules, reporting; a SPUTO of its own. | about 2 days, docs only |
| **2b: foreign-currency accounts** | Account `currency` field and migration (1); translation in books, trial balance, balance sheet, cash flow (3); foreign receipts, payments, transfers with rate capture and realised gain/loss (3); period-end revaluation of foreign bank balances (2); reconciliation in account currency (1.5); SOP/POP/HR settle into a foreign account with a rate (2); tests, isolation, mutation checks (2). | about 14.5 days, **provisional until 2a**, plus WEB |

Phase 1 is unaffected by Phase 2 except for one cheap precaution: new cash-book code never assumes the Company currency in a place Phase 2 would have to untangle (the book reads the account's currency through a single accessor that returns the base currency until the field exists).

### 9.7 Questions for Femi (his call)

1. **Which currencies may a Company open?** Any ISO currency, or a curated list per jurisdiction (for example GBP, EUR, USD, NGN, SLE)? The standing decision names only SLE for the Mano River four; "as they wish" needs his explicit word on LRD, GNF and XOF, which are zero-decimal (GNF and XOF would be `Money`'s first) and not onboarded.
2. **Rate source and entry:** typed per entry, a rate table with override, or both?
3. **Is the Company's base currency still the single reporting currency**, with foreign accounts translated into it (the assumption above)?
4. **A and B in 9.3:** does he want the architectural choice made in the IAS 21 design pass (recommended), or a view now?
5. **Order of work:** Phase 1 first and ship, then 2a and 2b (recommended), or hold the Cash Book until foreign accounts are designed?
