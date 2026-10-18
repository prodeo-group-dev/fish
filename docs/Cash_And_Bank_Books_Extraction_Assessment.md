# Cash and Bank Books (CBB) extraction assessment (docs only, Femi chooses the option before any build)

GL session, 2026-10-18. Shape follows `docs/Ecosystem_Extraction_DDD_Design.md` and `docs/Fixed_Assets_Extraction_Assessment.md`. **Nothing built, nothing moved.** Trigger (Femi, via CM): Cash and Bank Books is its own service, not part of GL; it is built inside GL today. The principle behind it: each sub-ledger owns its records, GL aggregates. The lock scope rule (Femi): only the accounts CBB owns, never Current Assets generally.

## 0. What is in GL today (read from master, not assumed)

| Layer | Content | Size |
|---|---|---|
| Domain `domain/ledger/` | `CashBook`, `CashBookEntry` (the receipt/payment command, built 2026-08-12), `CashBookKind` (CASH, BANK), `CashDirection`, `BankReconciliation`, `BankStatementLine` | about 530 lines |
| Use cases | List cash books, compute a cash book (per-account book with running balance, `ROW_LIMIT`), record a cash-book entry (receipt or payment), record a transfer between books, undo an entry, change an account's kind, list counter-accounts (the filtered picker), start, match, unmatch, complete, cancel, list and compute a bank reconciliation, the cash-balance helpers | about 1,000 lines |
| HTTP | `GET .../cash-books`, `GET .../cash-books/{accountId}` (the book), `.../counter-accounts`, `POST .../receipts`, `.../payments`, `.../transfers`, `.../entries/{id}/undo`, `PUT .../accounts/{id}/cash-book-kind`, `POST .../standard-accounts`; `GET/POST .../bank-reconciliations` with `match`, `unmatch`, `complete`, `cancel`, `GET {id}` | about 800 lines routes |
| Persistence | `bank_reconciliations`, `bank_statement_lines`, `bank_reconciliation_matches` (V28, V32 status); `accounts.cash_book_kind` (V33, a CHECK-constrained column on the chart itself) | 3 tables and a chart column |
| Policies | `CashBookPolicies` (settlement-account and bank-only-reconciliation policies, currently in log mode) | |
| Consumers | WEB (cash book and reconciliation screens); SOP, POP and HR post settlements to cash accounts directly through GL's thin interfaces, choosing the settlement account (default 1000) | |

**The structural fact that decides everything:** a cash or bank account is an ordinary GL account whose "book" is nothing but the ledger postings on it (SRS D4: account 1000 is always the Cash Book; bank accounts are further cash books). The book has **no state of its own**. CBB's own state is only: the cash/bank **kind** of an account, the **reconciliation** (statement lines and matches, which postings were cleared against which statement line) and the original-entry **commands** (receipt, payment, transfer, undo) that create a journal. Everything else is a read over the ledger.

## 1. What moves, what stays

**Moves to CBB:** the cash/bank kind (as CBB's own record per account), the receipt, payment, transfer and undo commands and their rules (counter-account validation, policies), the bank reconciliation aggregate and its three tables, the book read model (running balance, range, row limit), the counter-account picker, the reconciliation status feed for the Owner view.

**Stays in GL:** the Chart of Accounts including the cash and bank **accounts themselves**, Periods and the open-period check, journal posting and storage, the trial balance and statements (the cash line of the balance sheet and the cash-flow statement read the ledger, not CBB), the module-owned account list (`ModuleOwnedAccounts` stays the single place that says which accounts another module owns).

**Stays with the other sub-ledgers:** SOP's collections, POP's supplier payments and HR's pay run still post straight to GL's thin interfaces with a settlement account id; they do **not** go through CBB. CBB sees their effect because they are postings on the cash account.

## 2. The API between them

### 2.1 CBB to GL (service account, bypasses the EA membership check by design, like POP/SOP/IM/HR)

| GL endpoint | Purpose |
|---|---|
| `GET /companies/{c}/accounts/{accountId}/postings?from&to&cursor` (**new**) | The ledger postings on one account, in date order with the journal entry reference, description, counter-lines, source, reversal link: what the book is built from. This is the one genuinely new GL capability. |
| `GET /companies/{c}/accounts/{accountId}/balance?asOf=` (**new**, also wanted by Payroll) | The balance as at a date, for the reconciliation tie-out |
| `POST /cash-books/record-entry` (**new thin interface**, replaces the in-GL command) | Dr or Cr the cash/bank account against a counter-account, validated by GL (Company's own, active, not module-owned, the cash-book counter-account rule), idempotent on the entry id, answers the journal entry id |
| `POST /cash-books/record-transfer` (**new**) | Dr one cash/bank account, Cr another, one entry |
| `POST /cash-books/undo-entry` (**new**) | The reversal of a cash-book entry, linked to the original |
| `GET /companies/{c}/accounts?usableFor=` | Existing/proposed picker, so CBB never copies the exclusion list |
| `GET /companies/{c}/open-period` | Existing |

### 2.2 GL to CBB
None for posting. GL needs one fact from CBB for the lock (section 4): which accounts are cash/bank books. That stays an **account tag on GL's chart** (`cash_book_kind` already is), not a call to CBB at write time.

### 2.3 WEB and EA
WEB's cash and bank screens call CBB. EA gains a `CASH_BANK_BOOKS` managed module, declared withheld first and decoded by every consumer before any grant (the PAYROLL precedent). The Owner view reads CBB for cash by account and the reconciliation status.

## 3. Reconciliation

CBB owns it. For a bank account and a statement: CBB reads the account's postings from GL, matches statement lines to postings, and ties out against `GET .../balance?asOf=`. A reconciliation never changes the ledger; it only records which postings are cleared. The "reconciled" flag shown in the book is CBB's. Prevention of drift: a posting reversed in GL after being matched is flagged in the reconciliation as `ENTRY_REVERSED` (CBB re-reads reversal links), never silently dropped.

## 4. The lock (Femi's scope rule)

Keyed to an **explicit account tag**, never to the code 1000, the `ASSET` type or "Current Assets". The tag already exists: `accounts.cash_book_kind` (CASH or BANK), set by CBB's change-kind command. Only accounts carrying it are CBB-owned. Receivables (1100), Inventory (1300), prepayments and every other Current Asset carry no tag and stay open exactly as they are.

**Open for Femi (flagged, not decided):** what the lock refuses on a tagged account.
- **Recommended:** manual journals are refused (a manual journal straight to a cash or bank account bypasses the book of original entry and the reconciliation, the SRS premise that cash and bank are books of original entry); the services' settlement postings (SOP, POP, HR, and CBB itself) stay allowed through their own service principals.
- **Alternative (Femi's earlier remark that Cash stays open "to their own services and to manual journals as today"):** no manual-journal block; the tag only keeps cash accounts out of pickers that are not theirs. Femi chooses.

Tests either way: a Current Asset account (1100, 1300, a prepayment) stays writable by manual journals and by its own services; a non-tagged account coded 1000 stays writable; the tagged account follows the chosen rule; mutation checks on the tag test and the enforcement.

## 5. Data migration

`bank_reconciliations`, `bank_statement_lines`, `bank_reconciliation_matches` move to CBB's database (`cbb_production`); `accounts.cash_book_kind` **stays on GL's chart** (the lock needs it there) and CBB reads it, or CBB holds a mirror kept consistent through the change-kind command (to be decided with the Fixed Asset tag design, which has the same shape). Copy, verify (counts and matched totals per Company), cut over; GL's tables are dropped in a later migration, never the same release. Production data is legacy test data, so risk is low.

## 6. Options (Femi chooses)

- **A. Full extraction (recommended).** CBB owns commands, book, reconciliation. GL first adds the postings and balance reads and the three thin interfaces, then CBB is built, then WEB switches.
- **B. Reconciliation only.** CBB takes the reconciliation (the only part with its own state) and the Owner status feed; the book read and the receipt/payment commands stay in GL for now. Smallest move, but leaves "cash and bank books" half in GL, which is what Femi said it should not be.
- **C. Keep in GL.** Not recommended given Femi's direction.

## 7. Consumer-first order (Option A)

1. Decisions (this note); CM claims repo and infrastructure (`fish-cash-bank-books`, ECR, ECS, ALB, ACM host `cbb-api`, database `cbb_production`, Cognito service-account client CBB to GL, Jenkins job, `cbb.tf`).
2. **GL additive:** the postings and balance reads, the three thin interfaces, contract fixtures; the lock built but off behind a flag (`GL_ENFORCE_CBB_LOCK`, default off).
3. **EA** declares `CASH_BANK_BOOKS` (withheld); every consumer decodes it.
4. **CBB built** (scaffold, domain ported test-first, GL gateway, `CbbMembershipAuthorizer`, reconciliation).
5. Deploy CBB with no consumers; migrate the reconciliation tables; verify.
6. **WEB switches** its cash and bank screens; EA's Owner view reads CBB.
7. Enable the module; GL's cash-book and reconciliation routes stay as deprecated pass-through one release.
8. Lock on; remove GL's CBB code once no caller remains.

## 8. Size, cost, name

About 1,800 lines of use cases and routes and 530 of domain to port, plus tests; the same shape as HR's and POP's extractions. Rough elapsed effort: GL additive work 3 days (the postings read is the new piece), CBB service 5 to 6 days, migration and verification 1 to 2, WEB cut-over 3 (WEB session), infrastructure and CI 2 (CM): about three to four weeks of calendar time across sessions. One more service's recurring cost: ECS service, ALB rule, ACM host, database and role on the shared RDS, ECR repo, Jenkins job, Terraform, a Cognito client, logs and alarms, one more strict `/me` DTO to keep in step with EA.

- **Name:** Cash and Bank Books, short form **CBB**. **Repo** `fish-cash-bank-books`, folder `CBB`, package `com.theprodeogroup.cbb`, host `cbb-api.theprodeogroup.com`, database `cbb_production`, EA module `CASH_BANK_BOOKS`.

## 9. Open decisions for Femi

- **D1.** Option A (recommended), B or C.
- **D2.** What the lock refuses on a cash/bank-tagged account (section 4): manual journals too (recommended) or nothing.
- **D3.** Foreign-currency bank accounts stay out of scope (SRS), unchanged.
- **D4.** Where `cash_book_kind` lives after the move: on GL's chart (recommended, the lock needs it there).

## What I did not verify

I did not read WEB's cash and bank screens beyond locating the API files; the line counts are from `wc -l` of the files named above; the postings-read and the thin interfaces are proposals, not existing endpoints; and the effort figures are estimates, not measurements.
