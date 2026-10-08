# UAT 2026-10-08: remediation tracker

**Led by:** FiSH+ER WEB (at Femi's instruction, 2026-10-08: "Lead and coordinate the rest. Ask for collaboration from all peers that is impacted"). **Source:** `docs/reports/FiSH_UAT_Report_2026-10-08.pdf` (read-only UAT of production by the code-reviewer bot, 07:41-08:00 BST). **Verdict in the report:** not ready for sign-off; ledger arithmetic holds. 2 High, 7 Medium, 9 Low, 0 Critical.

**Rules in force:** only CM pushes, merges and deploys; each owner changes only its own checkout; nothing here changes who may do what (RBAC freeze, `docs/RBAC_SPUTO.md`); Femi decides anything marked DECISION. This file is the one place the status lives: owners update their rows by telling WEB, WEB edits the file.

Status key: **DONE-LOCAL** built, with CM for release; **ASKED** owner has been messaged; **DECISION** waiting for Femi; **OPEN** not started.

| ID | Finding | Owner(s) | Status | Next step |
|---|---|---|---|---|
| H1 | Fixed Asset Register (GBP 6,200) does not reconcile to GL account 1200 (GBP 1,200); the Car has no GL posting | **GL** (register and posting path); WEB shows funding choice | ASKED | GL to find why an asset can exist with no posting (was it created as "already owned", which should go to the suspense account, or by a path that posts nothing?), fix the path, add a register-vs-GL reconciliation check. WEB then shows the reconciliation result on the register. |
| H2 | Test and verification entries posted in live ledgers (Prodeo Trading x3, Prodeo Capital "Verification Laptop" and SN-VERIFY-001) | **Femi** (approval), **GL** (reversal journals), **CM** (a test tenant or staging) | DECISION | Femi approves dated reversal journals (not deletes). Then GL prepares them, CM runs them. Going forward no verification runs against production books; CM sets up a dedicated test Company or environment. |
| M1 | No deep links or session restore | **WEB**; CM (CloudFront must serve the app for `/fish/*`) | DONE-LOCAL (`fix/uat-2026-10-08-wave1`) | CM confirms `/fish/{companyId}/{view}` is served by the app, not a 403, then releases. |
| M2 | Unknown URLs render the marketing page | **WEB** | DONE-LOCAL (same branch) | Released with M1. |
| M3 | "FiSH 153" on the public landing page; two expansions of the acronym | **WEB**; **Femi** for the expansion | DONE-LOCAL for "153". DECISION for the expansion | Landing and header now both say "Financial Systems Handler". Femi confirms that one, or says "Financial Information Systems Handler"; it is one string in two files. |
| M4 | Browser blocks the EA API call on CORS from `capital.theprodeogroup.com`; Verification tab values come from an unknown source | **EA**; **CM** (config) | ASKED | EA confirms whether the allowed origin is missing or the preflight fails on a specific header; CM applies it. WEB then confirms the Verification tab and the banner show live values. |
| M5 | Administration > Companies is empty | **WEB** | DONE-LOCAL (same branch) | Lists the companies with the person's role. |
| M6 | No Trial Balance; VAT, invoices, bills, contacts, audit log and settings not in the navigation | **GL** (the report route), **WEB** (the screen); **Femi** (what the MVP navigation must contain) | ASKED, DECISION | GL has the trial-balance domain type but no HTTP route; GL adds `GET .../trial-balance?asOf=`, WEB builds the screen on that contract. Femi says which of VAT, invoices, bills, contacts, audit log, settings are MVP. Note: sales invoices and purchase bills exist under Operations > Sales and Purchases; they are named differently from what the tester looked for. |
| M7 | Overdrawn cash shown as a negative asset without warning | **WEB** | DONE-LOCAL (same branch) | Balance sheet now warns on any negative asset account. Dashboard flag can follow. |
| L1 | Slow "Loading..." before empty states (IM Items about 10 s) | **IM** (response time), **WEB** (skeleton states) | ASKED | IM looks at the Items list query; WEB adds skeleton and clearer loading states after. |
| L2 | Dashboard tiles "Unavailable" for Inventory, Cash flow, Profitability although the reports load | **EA** (it orchestrates those tiles); **WEB** | ASKED | EA says per tile whether the source failed, was empty, or was not asked for; the response should carry the reason so WEB can say "No data yet" or "Couldn't load" instead of "Unavailable". |
| L3 | Balance sheet: no total of liabilities and equity; "Retained earnings" appears twice | **WEB** | DONE-LOCAL (same branch) | Total added; the computed line is now "Earnings to date (not yet closed to retained earnings)". GL to confirm the computed line's meaning is as described. |
| L4 | IM empty state names "Create item" but the button is "+ New" | **WEB** | DONE-LOCAL | |
| L5 | "(UC-SM03)" shown to users | **WEB** | DONE-LOCAL | |
| L6 | Every dashboard load logs HTTP 409 on the sales-to-expense-ratio call | **GL**; **WEB** | ASKED | 409 for "no data" is the wrong status. GL moves to 200 with an empty body (or 204). WEB currently treats a 409 as "no data" and will accept both. |
| L7 | Copy nits: dates lack a year; "this Company" capitalisation; awkward tax copy | **WEB** | PARTLY DONE | Years added on journal and sales day headings. Capitalisation and tax copy: WEB to sweep in wave 2. |
| L8 | "Welcome back" dialog appears on every reload | **Femi** | DECISION | This is the deliberate shared-device check added 2026-09-29. Recommend keeping it (it stops someone opening the previous user's books). Options: keep as is; show it only after a period of inactivity or a new browser session. WEB will not remove it without Femi's word. |
| L9 | Placeholder company "xyz" in production; "Connect this Company to its school record in The Principal's EduSys" wording | **Femi/CM** (the data); **ER** and **WEB** (the wording) | ASKED | Femi/CM decide whether "xyz" is removed. ER and WEB settle the school-link wording; the phrase uses the product's own name today. |

## Second UAT pass (report section 6, not tested)

All write paths were out of scope by design. They need a **test tenant or staging environment**, set up by **CM**, with Femi's agreement on how it is separated from production. Until it exists nobody runs write tests against the live books (that is how H2 happened). Once it exists the pass covers: new journal, add asset, add account, add employee, run payroll (including the new approval screens), reconciliation, compute tax, school provisioning, invite and remove users, start a company, sign out; plus mobile layouts, accessibility and the Valiant's Hall groups beyond Finance.

## Order

1. **Now, in parallel:** CM releases WEB wave 1 (M1, M2, M3, M5, M7, L3, L4, L5, L7 part) after confirming the `/fish/*` path. GL starts H1 and the trial-balance route. EA answers M4 and L2. Femi answers the DECISION rows (H2 reversals, M3 wording, L8, M6 scope).
2. **Then:** GL's reversal journals and reconciliation check land; WEB builds the Trial Balance screen on GL's contract; CM stands up the test environment.
3. **Last:** second UAT pass on the test environment.

## What WEB will not do

Change who can do what; remove the "Welcome back" check; guess the trial-balance contract or the acronym; run any test against production books.

## Reports and prints (Femi, 2026-10-08: "We also need to work on the reports and prints")

**Where it stands (checked in code today):** only the sales invoice can be printed or saved as PDF. The Balance Sheet, Profit and Loss, Cash Flow, Working Capital, Receivables and Payables reports, the fixed-asset register and customer statements have no print layout; there is no export at all; and there is no Trial Balance. The UAT adds three related findings (M6 Trial Balance, L3 balance-sheet totals, M7 negative cash), already handled above. This is **Stage 5 of `WEB/docs/WEB_Customer_Experience_Scope.md`** (UC-CX4: an owner prints the Balance Sheet and P&L and hands them to a bank officer without editing anything), which was waiting on the shared figure formatter and table primitive; both are done, so it is next.

**What WEB will build (nothing needs a backend change, except the Trial Balance route):**

1. A shared `PrintableReport` wrapper: company name, report title, "as at" date or period, currency stated once, page numbers, repeating table headers, no split rows, A4 and Letter, same tabular figures. Negatives in parentheses and zero as `0.00` (the decisions already confirmed in the scope).
2. Roll-out in value order: Balance Sheet, Profit and Loss, **Trial Balance** (once GL has the route), Cash Flow, Working Capital, Receivables and Payables, fixed-asset register, customer statements, then bring the existing invoice onto the wrapper.
3. A "Save as PDF / Print" button on each report (client-side, via the browser's print dialog with the file name set to company, report and date, as the invoice does).
4. CSV export of each report, from the same data already on screen (so what is exported is what is shown). Open question for Femi below.

**Who is impacted and what WEB needs from them**

| Peer | Needs |
|---|---|
| **GL** | The trial-balance route (contract proposal: `GET /companies/{id}/trial-balance?asOf=` returning every account with debit and credit totals and the grand totals); confirm the meaning of the computed "earnings to date" line; confirm each report's "as at" or period fields are returned (balance sheet is currently "as of today"). A signed-off, dated report needs an as-at date a user can choose; today it is always now. |
| **EA** | The Company's legal name and jurisdiction for the print header (already on `/me`); whether a registered address and company number should print (not on `/me` today). |
| **SOP / POP / IM / HR** | Only if they want their own printable documents on the shared wrapper (SOP customer statements and invoice; POP purchase order and goods-received note; IM stock valuation; HR payslips). Each says whether it wants one; WEB builds them on the same wrapper in the order they ask. |
| **CM** | Release path only. |
| **Femi** | **DECISIONS:** (a) should reports allow an "as at" date other than today (needed for month-end and year-end packs); (b) is CSV export wanted now or after print; (c) which documents beyond reports must be printable first (payslips, purchase orders, statements). |
