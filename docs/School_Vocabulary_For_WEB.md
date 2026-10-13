# School vocabulary: the words a school Business Owner sees

**Status:** 2026-10-13, draft from the Education Runtime (+ER) session, for the WEB session to build as one label map. Docs only; nothing is built. **Words only.** Femi (Decisions_Log, 2026-10-12): "Schools should use the industry terminology such as admissions, enrollment, tuition". Hiding a module was **not** decided, so no row below removes anything; it only renames. This is the "ER supplies the vocabulary and OKs the labels" step from that entry and from the earlier navigation decision (2026-10-10: school labels stay untouched until ER OKs; this file is that OK).

## How to read it

- **Key:** WEB already has `moduleLabel(code, industry)` with `GENERIC` and `SCHOOL` vocabularies (`WEB/src/lib/moduleLabels.ts`); the school one is empty on purpose. Fill that one, and add the same shape for the non-module words below (a concept key per row, generic fallback, so a word not listed shows its generic word). A school Company is the one that holds the `EDUCATION_RUNTIME` module (`industryOfGrants`).
- **Status column:** **OK** = ER approves this word now (or Femi decided it, noted). **ASK FEMI** = still unanswered; the generic word stays until he answers (CM batches it). Decided 2026-10-13 (Decisions_Log): Enrolment (British); Buy = Purchasing (list "Purchases"); Stock = Stores; Ledger = Accounts; Profitability = Surplus; Profit and loss = Income and Expenditure; Revenue = Income; and the principle that a school is "not a hard-nosed business", so its words are the gentle school ones.
- **Rule of thumb I applied:** rename the words an owner *reads as business jargon that does not fit a school* (Sell, Customers, Sales today). **Keep accountants' statement and ledger words** (Journals, Trial balance, Balance sheet, Chart of accounts, Bank reconciliation, Fixed assets): a bursar or an external accountant expects them, and relabelling them would confuse the person who actually uses them. Keep **Business Owner** (Femi's own address for the owner).
- **Spelling:** **Enrolment** (British), decided by Femi 2026-10-13. The code and API already say "enrol".

## 1. Navigation (module level)

| Where | Generic word | School word | Status | Note |
|---|---|---|---|---|
| Module `SOP` | Sell | **Fees & Billing** | OK | A school's income is tuition and other fees raised through SOP (Decisions_Log 2026-10-12). Matches the Finance sub-tab that already carries this name |
| Module `POP` | Buy | **Purchasing** (the list is "Purchases") | OK (Femi) | decided 2026-10-13 |
| Module `IM` | Stock | **Stores** | OK (Femi) | decided 2026-10-13 |
| Module `GL` | Ledger | **Accounts** | OK (Femi) | decided 2026-10-13. Do **not** use "Bursary": the earlier "Bursary"/"Registry" was illustrative, not a Finance relabel |
| Module `TAX` | Tax | Tax | OK | unchanged |
| Module `HR` | People | **Staff** | OK | A school says staff; payroll beneath it stays a payroll word |
| Module `EDUCATION_RUNTIME` | Education | **Education Operations** | OK | already the school's own name |
| Hint for `SOP` | sales and customers | fees and guardians | OK | |
| Hint for `POP` | purchases and suppliers | purchases and suppliers | OK | unchanged |
| Hint for `IM` | inventory | school supplies and stores | OK | |
| Hint for `HR` | employees and payroll | staff and payroll | OK | |

Already school words and unchanged: **The Registry** (Administration), **Admissions**, **Fees & Billing** (Finance), **Education Operations**, **Students**, **Timetable**. Where WEB shows "Administration / Finance / Operations" for a school it already says "School Administration / School Finance / School Operations" (its mapping doc); keep that.

## 2. Dashboard tiles (The Registry)

| Generic tile | School word | Status | Note |
|---|---|---|---|
| Sales today | **Fees billed today** | OK | the tile is sales *raised* today (invoices), not money received, so "billed" is the honest word. If the tile ever shows receipts, change it to "Fees paid today" |
| Sales-to-expense ratio | **Fee income to expenses** | OK | |
| Money velocity / Expense velocity | unchanged | OK | money words, not industry words |
| Inventory | **Items in stores** | OK | follows Stock = Stores (Femi) |
| Cash flow | unchanged | OK | |
| Profitability | **Surplus** | OK (Femi) | decided 2026-10-13 |
| Business health | **School health** | OK | |

## 3. Everyday nouns and buttons

| Generic | School word | Status | Note |
|---|---|---|---|
| Customers / Customer | **Guardians / Guardian** | OK | the SOP Customer for a school is the guardian (Part 1 of the ER design note); "Parent" is the ER role alias, "Guardian" is the account word already on screen |
| Invoice(s) | **Fee invoice(s)** | OK | already used: "Fee invoices" |
| Sale(s) | **Fee(s)** | OK | |
| Revenue (statement line, tile) | **Income** | OK (Femi) | decided 2026-10-13; a school has other income (donations, boarding), so one word |
| Receivables | **Fees owed** | OK | the empty state "No customers recorded yet" becomes **"No guardians recorded yet"** |
| Payables | unchanged | OK | it is what the school owes suppliers |
| Aged / overdue receivables | **Fees outstanding** | OK | the "older than 30 days" label rule (Decisions_Log 2026-10-12) stays |
| Record a payment | **Record a fee payment** | OK | the fee desk verifies it (T-ER3), so the verb stays "record", not "receive" |
| Profit and loss | **Income and Expenditure** | OK (Femi) | decided 2026-10-13 |
| Suppliers, Purchase Orders, Items | **Suppliers, Purchase Orders, Store items** | OK | Items follows Stock = Stores |
| Warehouses | **Store rooms** | OK | follows Stock = Stores |
| Adjustments | **Store adjustments** | OK | follows Stock = Stores |
| Employees | **Staff** | OK | the button "Add employee" becomes **"Add staff member"** |
| Run payroll / Pay runs / Salary advances | unchanged | OK | payroll words are the same in a school |
| Team | **Staff access** | ASK FEMI | the word "Staff and roles" is **reserved** for ER's own school-roles screen (WEB mapping doc, 2026-10-10), so Team must not take it; or keep "Team" |
| Companies / Company profile | **Schools / School profile** | OK | "+ Add another company" becomes **"+ Add another school"**; fields "Registered name / Registration number" stay (they are legal facts) |
| Verification: "Business (KYB)" | **School (KYB)** | OK | |
| Business Owner | unchanged | OK | Femi's own address for the owner; do not change to "School Owner" |
| Tax: "Corporate income tax" | unchanged | OK | a statutory name |
| Admissions, Enrolment, Tuition | **Admissions, Enrolment, Tuition** | OK (Femi: Enrolment) | the school's own words. Use **Tuition** for the fee-schedule item and invoice line, **Term** for a billing cycle |

## 4. Empty states (what a new school sees before anything exists)

| Today | School wording | Status |
|---|---|---|
| "No fee invoices issued yet." | unchanged | OK |
| "No customers recorded yet." | "No guardians recorded yet." | OK |
| "No guardians on file yet." | unchanged | OK |
| "No admission applications yet." | unchanged, plus the create control WEB owes (UAT 2026-10-12) | OK |
| "No students enrolled yet." | "No students enrolled yet." (**enrolled** is also British and American) | OK |
| "No lessons scheduled yet." | unchanged | OK |
| "No Purchase Orders in fulfilment yet." | unchanged unless Buy is renamed | OK |
| "No items created yet - use 'Create item'" (button says "+ New") | "No store items yet" with button "Add item" (fixes the label mismatch UAT found) | OK |
| "No employees added yet - use 'Add employee'" | "No staff added yet - use 'Add staff member'" | OK |
| "No pay runs yet" | unchanged | OK |
| "No fee invoices" screen for an admin with no fee desk | plus the hint: "No one can raise invoices yet: add a bursar or fee officer." | OK (T-ER10; WEB owes the hint) |

## 5. What this does not do

- It hides nothing. Whether a school should see Buy, Stock, People, the Ledger's manual journal or the business dashboard tiles at all is a separate question that Femi did **not** answer; ask again only for a specific module.
- It does not rename anything in an API, route, role or wire value. Only text a person reads.
- It does not touch the other runtimes: a future runtime adds its own vocabulary the same way.

## 6. Still open for Femi

1. **Team** (People, Team): **Staff access**, or keep **Team**? Unanswered; keep **Team** until he answers. "Staff and roles" stays reserved for ER's school-roles screen.

Answered 2026-10-13 and applied above: Enrolment (British); Buy = Purchasing (list "Purchases"); Stock = Stores; Ledger = Accounts; Profitability = Surplus; Profit and loss = Income and Expenditure; Revenue = Income. The guiding principle he gave: a school is not a hard-nosed business, so where a business word and a gentler school word both fit, use the school word.
