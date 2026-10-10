# GL Cash and Bank Books: Backlog (SPUTO: Task and Order)

**Status:** 2026-10-10, GL session. Planning only; nothing built. **Urgent, high priority** (Femi). Requirements in `docs/GL_Cash_And_Bank_Books_SRS.md`, use cases in `docs/GL_Cash_And_Bank_Books_Use_Cases.md`. Table format follows `docs/GL_POP_IM_SOP_Backlog.md`. Sizes are GL's own estimates in working days, tests and mutation checks included. CM reviews every GL item at HIGH (money and posting); CM alone merges and deploys. Nothing starts until Femi confirms the decisions marked in the SRS (section 3) and CM releases the hold on GL code that applies until the UAT sitting is done.

## Order of work

Three releases, each shippable and each safe on its own. The ordering rule that matters most: **cash flow (T6) ships before any Bank account exists (T9)**, because the cash-flow statement reads only account `1000` today and would silently omit a bank account.

| Release | Contents | Outcome for the owner |
|---|---|---|
| **A: kinds and books (read)** | W1 and W2 | Cash and bank accounts exist as a concept; each has a book with a running balance; cash flow is correct; existing Companies can add a bank account. |
| **B: books of original entry** | W3 | Money in, money out and transfers are recorded in the books. |
| **C: tighten and connect** | W4 and W5 | Reconciliation is bank-only; services settle into a chosen cash/bank account. |

## W0: decisions and housekeeping

| # | Item | Owner | Depends on | Status |
|---|---|---|---|---|
| C0 | Femi confirms D2, D3, D5 to D8 and the per-country mapping in D4 (SRS section 3). Already confirmed: D1 (one book per account) and the D4 rule (the prime account is `1000` and depends on the jurisdiction). | Femi via CM | none | open |
| C1 | CM releases GL code work (held until after the UAT sitting) and picks the migration number (V33 or later; the Period and fixed-asset-link work also want one). | CM | C0 | open |
| C2 | Claim row in `docs/GL_POP_IM_SOP_Coordination.md` (done in this docs branch). | GL | none | done |
| C3 | Check consumers of `JournalSource` and of `GET accounts` for strict decoding (SOP, POP, IM, HR, EA, WEB) before `CASH_BOOK` and `cashBookKind` ship. Output: yes/no per consumer. | GL with each session | none | open |

## W1: account kind (Release A, part 1)

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| T1 | `CashBookKind` and `Account.cashBookKind` with the ASSET-only invariant; migration (`cash_book_kind`, CHECK; `jurisdictions.prime_cash_book_kind` and `prime_account_name` with the proposed per-country seed; backfill each existing `1000` to its Company's jurisdiction kind); repository mapping; domain and persistence tests. | GL | C1, C0 | 1.5 | open |
| T2 | Account routes: optional `cashBookKind` on create; `PUT .../accounts/{id}/cash-book-kind`; field on `GET accounts`; BANK cannot be cleared while a reconciliation exists; route-inventory and isolation-matrix classification (people-only, WRITE). | GL | T1 | 1 | open |
| T3 | "Add missing template accounts" use case and route (`1010 Bank` and `2150`; skips and reports codes already used; idempotent) with tests including the 13de72e4 shape (chart without 2150). | GL | T1 | 1 | open |

## W2: books and cash flow (Release A, part 2)

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| T4 | Repository method for the posted lines of one account between two dates (uses `idx_journal_lines_account_id`); `GET .../cash-books` list with balances. | GL | T1 | 1 | open |
| T5 | `GET .../cash-books/{accountId}?from=&to=`: opening, rows, running balance, totals, reversal flag, `range_too_large`, 409/404 rules; running balance equals the trial-balance figure in a property test (NFR-CB02). | GL | T4 | 1.5 | open |
| T6 | **Cash-flow statement over all CASH and BANK accounts** (IAS 7 cash and equivalents; transfers excluded); regression: a `1000`-only Company gives identical output to today. | GL | T1 | 1 | open |
| T7 | Posting contexts (sales, purchase, payroll) return additive `cashAndBankAccounts`; existing `cashAccountId` unchanged. | GL | T1 | 0.5 | open |
| T8 | `reconciled` flag per row for bank accounts from completed reconciliations (Should). | GL | T5 | 0.5 | open |
| T9 | Seed the prime account `1000` and the second account `1010` in all five chart templates and `AddCompanyToTenantUseCase`, kinds and names from the jurisdiction (D4); `accountsFor` takes the jurisdiction; fallback for an unknown jurisdiction. **Last item of Release A**: only after T6 is live and verified. | GL | T6, T1 | 1 | open |
| W-A | WEB: Cash and Bank section (list, book with range, print/CSV), "Add a bank account" prompt, honest empty states, layout checklist. | WEB | T2, T5 | WEB to size | open |

**Release A gate:** T6 live and verified before T9. First Tenant's cash-flow figures unchanged (snapshot regression on `1000`-only Companies).

## W3: original entry (Release B)

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| T10 | `JournalSource.CASH_BOOK` (or fallback `MANUAL`, per C3). | GL | C3 | 0.25 | open |
| T11 | Record receipt and payment use case and routes through `PostJournalEntryUseCase`; counter-account rules incl. module-owned control accounts resolved by the posting contexts' own resolvers, not code literals; `Idempotency-Key`; named errors; `cash_below_zero` warning (Should). | GL | T5, T10 | 2 | open |
| T12 | Transfer between two cash/bank accounts (one entry, both books; no cash flow). | GL | T11 | 0.5 | open |
| T13 | Tests that matter: idempotent replay; concurrency (two receipts at once); reversal shows two rows; counter-account refusals; isolation matrix and guess-the-id; source scan "all entries via PostJournalEntryUseCase" (NFR-CB03); mutation checks on each refusal. | GL | T11, T12 | 1 | open |
| W-B | WEB: Money in / Money out / Move money forms in each book, plain-language counter-account picker, Undo. | WEB | T11, T12 | WEB to size | open |

## W4: tighten (Release C, part 1; refusals only, log-first)

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| T14 | Reconciliation start requires a BANK account: log-first flag, then enforce (`FISH_CASHBOOK_BANKONLY_MODE`, the G3 pattern). Grandfather: owners flag `1000` BANK first (UC-CB2). | GL | T2, C0 | 0.5 | open |
| T15 | Settlement account for collection/payment/pay run must be a cash/bank account of the Company: log-first, then enforce. | GL | T7, SOP/POP/HR consumers | 0.5 | open |

## W5: services choose the account (Release C, part 2)

| # | Item | Owner | Depends on | Size | Status |
|---|---|---|---|---|---|
| T16 | SOP: cash sale and collection take a chosen `settlementAccountId` from `cashAndBankAccounts` (default `1000`). | SOP | T7 | SOP to size | open |
| T17 | POP: supplier payment settlement picker from the same list. | POP | T7 | POP to size | open |
| T18 | HR: pay run `cashAccountId` choice. | HR | T7 | HR to size | open |
| W-C | WEB: account pickers on the three screens; reconcile action on bank accounts only. | WEB | T7, T16 to T18 | WEB to size | open |

## Sizes

| Release | GL days |
|---|---|
| A: T1 to T9 | 9 (T1 1.5, T2 1, T3 1, T4 1, T5 1.5, T6 1, T7 0.5, T8 0.5, T9 1; T9 closes the release) |
| B: T10 to T13 | 3.75 |
| C: T14, T15 | 1 |
| **Total GL** | **about 13.75 days** |

WEB, SOP, POP and HR sizes are theirs. A shorter first slice if Femi wants something fast: **T1, T2, T4, T5, T6, T9 (about 7 days)** gives owners a bank account and a book, with cash flow correct, before any entry-side work.

## What each session is asked

- **CM:** confirm review gating (HIGH on all of W1 to W4), release the hold when appropriate, choose the migration number, and run the 2150/Bank backfill decision (T3 is self-service per Company; no mass data job is needed).
- **WEB:** read the SRS and use cases; design the Cash and Bank section and the pickers with the section-7 layout checklist; plain-language labels; tell GL anything the API shape should change before T5 and T11 are built.
- **SOP, POP, HR:** nothing before Release C; they should read FR-CB50 to CB52 and confirm they can send a chosen account.
- **EA:** no change expected; confirm no cash tile depends on `1000` alone.
- **Femi:** confirm D2 to D8; say whether the seven-day slice is the first release.

## Verification before each release

Release A: a Company with only `1000` shows an unchanged cash flow; a Company with both accounts shows summed cash flow with a transfer excluded; the book's closing balance equals the trial balance's account balance; isolation matrix green. Release B: the receipt/payment path is idempotent and reversible, the 17-route posting isolation suite still passes with the new routes, nothing posts to a control account. Release C: `WOULD BLOCK`-style log lines read for one cycle before enforce.
