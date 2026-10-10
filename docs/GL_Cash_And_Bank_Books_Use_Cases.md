# GL Cash and Bank Books: Use Cases (SPUTO: Use cases)

**Status:** 2026-10-10, GL session. Requirements only. Traces to `docs/GL_Cash_And_Bank_Books_SRS.md` (FR/NFR/D numbers). Plain-language wording is what WEB shows; the accounting terms are in brackets for accountants.

Actors: **Owner** (Business Owner / Owner-Admin), **Accountant** (staff with WRITE at the Company), **Reader** (READ only), **Service** (SOP, POP, HR with their service logins).

## UC-CB1 Add a cash or bank account
- **Actor:** Owner, Accountant (WRITE). **Pre:** signed in; a Company selected.
- **Main flow:** (1) Opens Cash and Bank. (2) Chooses "Add a bank account" (a bank, or a mobile-money wallet such as Orange Money or MTN MoMo, which is simply another bank account) or "Add a cash account (till, petty cash)". (3) Enters a name (and optionally a code; default is the next free `10xx` from `1010`). (4) GL creates an ASSET account, CURRENT, with the kind set. (5) It appears in the list with a zero balance.
- **Alternate:** code already used by another account: 409 `account_code_in_use`, suggests the next free code. Name empty: 400.
- **Post:** an ordinary GL account exists with `cashBookKind`; trial balance unchanged (zero balance).
- **Traces:** FR-CB01, CB02, CB06, CB61.

## UC-CB2 Mark an existing account as cash or bank (not `1000`)
- **Actor:** Owner, Accountant (WRITE). **Pre:** an ASSET account exists that is not `1000` (account `1000` is always the Cash Book and its kind cannot be changed: 409 `prime_cash_book_kind_fixed`).
- **Main flow:** (1) Opens the account, chooses "This is a bank account" (or cash). (2) GL sets the kind. (3) A bank account can now be reconciled.
- **Alternate:** non-ASSET account: 409 `kind_requires_asset_account`. Clearing BANK when a reconciliation exists: 409 `reconciliations_exist`.
- **Traces:** FR-CB01, CB02, CB06; Risk 4.

## UC-CB3 See my cash and bank accounts
- **Actor:** Owner, Accountant, Reader (READ). **Main flow:** (1) Opens Cash and Bank. (2) Sees each cash/bank account with its kind, balance, and for banks the date last reconciled. (3) Chooses one to open its book.
- **Alternate:** no cash or bank account: shows "Add a bank account" (UC-CB1).
- **Traces:** FR-CB12, CB61.

## UC-CB4 Read an account's book
- **Actor:** Owner, Accountant, Reader (READ). **Pre:** a cash or bank account.
- **Main flow:** (1) Opens the account's book. (2) Picks a date range (default this month). (3) GL returns the opening balance, then each posting in date order with money in, money out and a running balance, then totals and the closing balance. (4) For a bank account each row shows whether it has been cleared in a reconciliation. (5) The user may print or export (WEB).
- **Alternate:** account not cash/bank: 409 `not_a_cash_or_bank_account`. Account of another Company, or unknown: 404. Range too large: `range_too_large`. Reversed entries show the reversal as its own row.
- **Post:** read-only; nothing changes.
- **Traces:** FR-CB10, CB11, CB13, CB14; NFR-CB02, CB04.

## UC-CB5 Record money in (receipt)
- **Actor:** Owner, Accountant (WRITE). **Pre:** the cash/bank account exists; a counter-account is available (income, a loan, owner's capital, other).
- **Main flow:** (1) In the account's book chooses "Money in". (2) Enters date, amount, what it was for (the counter-account, picked from plain-language groups), a note and optional reference. (3) Submits with an idempotency key. (4) GL posts debit book account, credit the counter-account, source `CASH_BOOK`. (5) The row appears in the book and the balance updates.
- **Alternate:** counter-account is AR, AP, VAT, Inventory, Fixed Assets, Suspense or Opening-balance equity: 409 `counter_account_not_allowed` and the message says "Customer payments are recorded under Sales, collections" (D5). Amount not positive: 400. Counter-account equals the book account: 400. Resubmitted with the same key: the first result is returned, nothing posts twice. No open Period: 409 `no_open_period` (see the Period scoping).
- **Post:** one balanced POSTED journal entry; the account's GL balance moves by the amount.
- **Traces:** FR-CB20, CB22, CB23, CB26; NFR-CB03, CB06.

## UC-CB6 Record money out (payment)
- Same as UC-CB5 with the sides reversed (debit counter-account, credit book account); supplier payments are refused for the same reason and point to Purchases, Pay supplier.
- **Alternate (cash):** the payment takes a cash account below zero: succeeds with warning `cash_below_zero` ("You have recorded spending more cash than you had"); for a bank account it is an overdraft shown as a liability in the balance sheet.
- **Traces:** FR-CB21, CB22, CB25; D8.

## UC-CB7 Move money between my accounts (transfer)
- **Actor:** Owner, Accountant (WRITE). **Main flow:** (1) In a book chooses "Move money to another account". (2) Picks the other cash/bank account, date, amount. (3) GL posts debit the receiving account, credit the paying account, one entry. (4) It appears in both books as money out of one and money in to the other.
- **Alternate:** same account both sides: 400. Not a cash/bank account: 409.
- **Post:** cash flow statement shows no cash flow for it (UC-CB11).
- **Traces:** FR-CB24, CB40.

## UC-CB8 Correct a wrong entry
- **Actor:** Accountant (WRITE). **Main flow:** (1) Selects the entry in the book, "Undo". (2) GL posts a reversing entry (existing reversal use case). (3) Both rows show in the book; the balance is back; the user records the right entry.
- **Alternate:** the entry was already reversed: 409. Entry in a closed Period: 409 (when Period close exists).
- **Traces:** FR-CB26, CB10.

## UC-CB9 Reconcile a bank account
- **Actor:** Owner, Accountant (WRITE). **Pre:** a BANK account; the bank statement lines and ending balance.
- **Main flow:** the existing flow (start with the statement, match each line to a posted entry, unmatch, complete or cancel), now offered only for bank accounts; completed matches mark rows "cleared" in the book (UC-CB4).
- **Alternate:** account is not BANK: `reconciliation_requires_bank_account` (log-first, then refused; D7). Balance tie-out is the existing switch (`enforceBalanceTieOut`), unchanged.
- **Traces:** FR-CB30, CB31, CB14.

## UC-CB10 Choose the cash or bank account when selling, paying or running payroll
- **Actor:** Service on behalf of a person (SOP cash sale / collection, POP supplier payment, HR pay run). **Main flow:** (1) The service reads the posting context, which now lists `cashAndBankAccounts`. (2) WEB shows the choice (default: the Company's cash account `1000`, as today). (3) The service sends the chosen `settlementAccountId` / `cashAccountId`. (4) GL posts as today to that account.
- **Alternate:** chosen account is not a cash/bank account of the Company: logged first, then 409 `settlement_account_not_allowed` (FR-CB52).
- **Post:** the posting shows in that account's book with source of the originating module, not `CASH_BOOK`.
- **Traces:** FR-CB50, CB51, CB52.

## UC-CB11 Cash flow statement with cash and bank
- **Actor:** Owner, Accountant, Reader; EA dashboard. **Main flow:** the statement sums cash and bank accounts as cash and cash equivalents: opening, closing, net cash flow; transfers between them are excluded.
- **Alternate:** the Company has only `1000`: identical to today. No cash/bank account at all: 409 `no_cash_account` (as today).
- **Traces:** FR-CB40; Risk 1.

## UC-CB12 Add missing standard accounts to an existing Company
- **Actor:** Owner (Owner-Admin) or CM (one-off). **Pre:** an existing Company whose chart predates the current template.
- **Main flow:** (1) Triggers "Add missing standard accounts". (2) GL compares the Company's chart with its template and adds what is missing (the VAT control account `2150`, kind CASH on `1000`), never overwriting. It does not add a Bank account. (3) Returns what was added and what was skipped (code already used by another account).
- **Post:** idempotent; running twice adds nothing the second time.
- **Traces:** FR-CB60, CB61; the 2150 gap found on Company `13de72e4`.

## UC-CB14 A new Company gets its Cash Book and its currency
- **Actor:** Owner creating a Company (or GL on their behalf). **Pre:** the Company has a jurisdiction.
- **Main flow:** (1) The Company is created. (2) Its currency is the jurisdiction's currency (UK GBP, IE EUR, NG NGN, SL SLE; LR, GN and CI follow the standing SLE-only decision unless Femi says otherwise). (3) GL seeds the chart as before, with account `1000 Cash` as the Company's Cash Book (kind CASH) in that currency. (4) First opening balance, sales, collections, payments and payroll default to `1000`. No bank account is seeded: the owner adds one when wanted (UC-CB1).
- **Alternate:** the request names a currency that is not the jurisdiction's: 409 `currency_not_supported_for_jurisdiction`. Unknown or disabled jurisdiction: refused as today.
- **Traces:** FR-CB04, CB07, D3, D4.

## UC-CB13 Opening balance of a cash or bank account
- **Actor:** Owner, Accountant (WRITE). Uses the existing opening-balance route for the account; the book's first row shows the opening balance; the contra is Opening-balance equity as today.
- **Traces:** FR-CB70.

## Use case coverage

| Requirement | Use cases |
|---|---|
| Two kinds, bank has reconciliation | UC-CB1, 2, 9 |
| They are GL accounts | UC-CB1 (post: ordinary account), UC-CB11 |
| Books of original entry | UC-CB5, 6, 7, 8 |
| One book per account | UC-CB3, 4 |
| Services settle into them | UC-CB10 |
| Existing Companies | UC-CB2, 12 |
| The Company's currency comes from its jurisdiction; `1000` is its Cash Book | UC-CB14 |
