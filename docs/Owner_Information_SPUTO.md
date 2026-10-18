# The Business Owner's information: what EA needs from each service, and how to make sense of it (SPUTO)

**Status:** 2026-10-18, planning only, nothing built. Written by the EA session at Femi's request ("determine what data you need from all the services that are running and determine how to make sense of them", services named: SOP, IM, POP, PAY, HR, GL; and "research what day to day information a CEO/Business Owner requires"). It builds on `docs/EA_Dashboard_At_A_Glance_Playbook.md` and `docs/EA_Dashboard_Owed_Ageing_Cutover_Note.md` and does not redo them.

**Evidence, and how much to trust it.** Four researchers reported on 2026-10-18; their sources are cited by name below.
- **[R1] Owner information needs** (web research): cadence guidance is consistent across sources but is mostly practitioner and vendor advice, not research. There is no authoritative standard for "the owner's dashboard". Every benchmark number is a vendor rule of thumb, so this document gives none as a target. The oft-quoted "82% fail from cash flow" figure could not be verified and is not used.
- **[R2] What leading small-business products show owners** (web research): Xero, QuickBooks, Zoho, FreshBooks, Wave, Kippa verified in part; Sage and freee could not be verified. No study of which tiles owners ignore exists, so none is claimed.
- **[R3] West Africa, UK, Ireland and school owners** (web research): Sierra Leone evidence is thin; the National Revenue Authority site could not be read; several statutory dates are unverified and are marked as questions for Femi, not facts.
- **[R4] Field-level read of the services' read routes** [code], on `origin/master` of GL 29cd6bc, SOP 7f01125, POP 83fdbbc, IM 6ccd734, HR 727b6c2 (2026-10-16 to 18). Read-only, not run against live services.
- **[doc]** a repo document; **[decided]** in the Decisions_Log; **[proposed]** this note's proposal; **[unverified]** not checked.

Principles this note obeys and does not reopen: **the services hold the details and GL aggregates** (Femi, 2026-10-18: POP payables, SOP receivables, IM stock, Payroll, HR/Personnel; "EA the Business Owner's view"); **Prodeo is a landlord with no role in a Tenant's data** (the Owner sees only their own business); **preparation is not audit** (FiSH prepares and analyses and its accuracy is its own onus, the Tenant owns the records); the Owner view is **Owner-Admin only** and online only, with nothing of the business stored on the phone; **no outside-adviser gates**, tax and accounting questions go to Femi.

---

## 1. Scope (S)

**The problem.** The Business Owner runs a small business, increasingly from a phone. Six services hold the facts (SOP, IM, POP, PAY, HR/Personnel, GL). Each answers its own questions. The Owner asks different questions that cut across them ("Can I pay my bills this week?"). EA is the Owner's view: it must know which facts to fetch, from whom, how to combine them without lying, and how to say what they mean.

**In scope:** the Owner's recurring questions; the data each question needs and which service holds it; what EA already shows, what exists but is unused, and what is missing; how to interpret each figure honestly; what to ask each service; the order.

**Out of scope here:** building any of it; the Education Runtime's school-specific data (named in section 6 so it is not forgotten, but ER is not one of the six services in this pass); Omniview and market analysis (parked until after Live); statutory filing by API.

---

## 2. What the Owner needs to know (U, the questions)

The questions are phrased as the Owner would ask them [R1, built from accountancy, bank and government guidance]. **Status** says where the answer comes from today: **D** = already on EA's dashboard; **R** = a route exists but EA does not use it; **M** = missing or only partly available.

| # | Owner's question | Figure | Holder | Status |
|---|---|---|---|---|
| **Needs a decision or is due soon** | | | | |
| 1 | What needs my decision today? | pending approvals across services | SOP, IM, POP, HR/PAY via EA's approvals queue | **D** (customer returns, stock adjustments, supplier returns, pay runs). **M**: purchase orders awaiting approval (POP `pending-action` exists, not in the queue), leave, advances and expense claims (HR has them per employee only) |
| 2 | What must I pay in the next 7 days, and can I cover it? | payables due soon against cash | POP due dates, GL cash | **M**: POP has only due-date ageing buckets, no "next due" list; the "next due" tile is planned (Dashboard Playbook P3) |
| 3 | Is a payroll or a tax payment coming, and how much? | next pay run, statutory amounts and dates | PAY, tax | **M**: no statutory records exist until the Payroll subledger is built; no due-date calendar anywhere |
| 4 | Is any verification or compliance step overdue? | KYB, phone, deadlines | EA | **D** |
| **Cash** | | | | |
| 5 | How much cash do I have right now? | cash and bank balances | GL `cash-books` | **R**: GL has it per account; the dashboard shows the trend, not a balance per account |
| 6 | How has my cash moved lately, and where did it come from and go? | cash trend, cash flow by activity | GL `cash-balance-series`, `reports/cash-flow` | **D** |
| 7 | Did money arrive today? | receipts | GL cash books (rows), SOP | **M** as a single owner-level view; per cash book drill-down exists |
| 8 | Is my bank balance matching my books? | reconciliation status | GL `bank-reconciliations` | **R** |
| **Money owed** | | | | |
| 9 | Who owes me, and how late? | receivables total, overdue, by age | GL control total; SOP ageing | **D** total and "older than 30 days" from GL; **M** SOP receivables ageing and due dates (proposed shape in the Ageing Note) |
| 10 | Who do I owe, and how late? | payables total, overdue, by age | GL control total; POP ageing | **D** from GL; **R** POP `accounts-payable-due-date-aging` (needs the currency as a parameter); cut-over designed, not built |
| 11 | Which big invoices are overdue and have I chased them? | top overdue customers | SOP customers-with-balances | **R** (balance per customer exists; no chase record) |
| **Sales and profit** | | | | |
| 12 | How are sales today and this week against normal? | sales net of VAT, versus comparison | SOP `sales`, `sales-performance` | **D** "sales today" (net, Femi 2026-10-15). **M**: no comparison against the same day or week of last year anywhere |
| 13 | Am I making money this month? | revenue, gross profit, net profit | GL P&L, trading P&L | **D** (period to date, open period only) |
| 14 | Am I earning enough on each sale? | gross margin and trend | GL trading P&L | **D** but only correct if cost-of-sales accounts are tagged (see section 4) |
| 15 | Where is the money going? | operating expenses by category | GL accounts, P&L | **M**: no by-category expense view; GL expense velocity gives one total rate |
| 16 | Did I hit my plan? | budget versus actual | none | **M**: no budget exists in any service |
| 17 | Which customers or products are actually profitable? | profitability by customer and product | SOP, IM, GL | **M** |
| **Stock** | | | | |
| 18 | What stock do I hold and what is it worth? | stock quantity and value | IM `items` | **D** (inventory summary) |
| 19 | What is running out? | low-stock items, reorder | IM `inventory-levels`, `stock-velocity` | **M** as an owner view: both are per item, there is no company-wide low-stock list |
| 20 | Is stock selling or sitting? | turnover, slow and dead stock | IM, SOP, GL | **M** |
| **People and payroll** | | | | |
| 21 | How many people work for me, and what do they cost? | headcount, payroll cost per period, share of revenue | HR/Personnel, PAY | **M**: headcount exists (`employees` list), not by division; payroll cost needs the run list; no one-call summary |
| 22 | What leave and advances are outstanding? | leave liability, advances owed | HR, PAY, GL | **M**: per employee only; leave liability in money is in the ledger |
| **Tax and compliance** | | | | |
| 23 | What tax do I owe or must I set aside? | VAT/GST owed, payroll taxes withheld, income tax | GL, PAY, tax | **M**: GL has corporate income tax records and VAT categories but no VAT return history to read; payroll taxes await the Payroll subledger |
| 24 | What filings and licence renewals fall due, and when? | statutory calendar | tax docs | **M**: reference data exists per jurisdiction (`docs/<CC>/..._Tax_And_Currency_Settings.md`); no calendar and no per-business due-date tracking |
| **Position** | | | | |
| 25 | What do I own and owe? | balance sheet, working capital | GL | **D** |
| 26 | Is the business getting stronger over time? | the same figures across periods | GL | **M**: reports are period to date; there are no stored period comparisons |

**Not asked of any service, by design:** budget and plan, and market data. They are named so nobody assumes they exist.

---

## 3. What EA pulls today, and what it leaves unused

**Used by the dashboard [code, EA `ComputeDashboardUseCase` and the approvals queue]:** SOP sales list; IM items; GL cash flow, profit and loss, balance sheet, working capital, trading profit and loss, the 30-day cash series and the receivables and payables summary; and, for the approvals queue only, SOP return requests, IM pending adjustments, POP fulfilment and HR payroll run submissions. A failing source blanks one tile, not the page.

**Routes that exist and EA does not use [R4]:** GL `cash-books`, `bank-reconciliations`, `money-velocity`, `expense-velocity`, `sales-to-expense-ratio`, `open-period`, `fixed-asset-register`, `trial-balance`, `customers`, `sales-invoices`; SOP `sales-performance`, `returns-analytics`, `customers-with-balances`; POP `accounts-payable-due-date-aging`, `purchase-orders/pending-action`, `suppliers`; IM `inventory-levels`, `stock-velocity`; HR `employees`, `leave-balance`.

---

## 4. Gaps and cautions, by service [R4]

**Cross-cutting**
- **Single Company only.** No route aggregates across Companies; an Owner of several Companies needs one call per Company and per report. There is no group roll-up anywhere.
- **Open-period dependence.** GL's `money-velocity`, `expense-velocity`, `sales-to-expense-ratio`, the P&L without dates, trading P&L and cash-flow without dates answer 409 `no_open_period` when no Period is open. An Owner view must say "no open period" plainly, not fail.
- **Cost of fan-out.** Every service asks EA `GET /me` on every request. A phone home screen that fans out to six services multiplies that. Several routes also read every journal entry on every call (GL trial balance, balance sheet, working capital, receivables and payables summary), so they slow as the ledger grows.
- **Unpaged full lists** (GL journal entries and sales invoices; SOP sales and return requests; POP fulfilment and pending-action; IM items; HR employees and payroll runs) are unsuitable for a phone.
- **People-only.** The GL reports cannot be called by a service account, so the Owner view is always the signed-in person's own token, as the dashboard already does.

**GL.** The trading profit and loss is only right if the owner has tagged cost-of-sales, interest and income-tax accounts (`costOfSalesConfigured`, `interestConfigured` say whether). An untagged account counts as operating expense, which overstates gross profit and understates operating profit. Retained earnings accumulate across all time (no period close). "Overdue" is "older than 30 days since the sale or purchase date", not past a due date. A tagged payment larger than its supplier's tagged charges can leave the total above the control balance (a known accepted limit). **GL does not check the module grant on its read routes except Tax, so any member with READ at a Company can read every GL report even without the GL module (a code comment calls it "a real, known gap").** I flag this to CM for a security decision; it matters here because the Owner view must not become the way staff see figures the Owner has withheld.

**SOP.** No receivables ageing and no due dates (payment terms are being defined); `sales-performance` has no date filter and spans every order ever; `customers-with-balances` calls GL in the same request; facility headroom persistence is unconfirmed.

**POP.** Due-date ageing needs the currency passed in and puts "not yet due" and "up to 30 days overdue" in one bucket; no list of closed or paid purchase orders; no company-wide payments list.

**IM.** Stock value is the sum of `totalValue` over a full unpaged list; low-stock and velocity are per item.

**HR and Payroll.** No company-wide pending leave, expense-claim or advance list (per employee only); no headcount by division (division is not recorded); no statutory amounts or due dates until the Payroll subledger exists. HR offered to add company-wide pending lists and a summary route (2026-10-18).

---

## 5. How to make sense of the numbers (P, requirements)

**The honest-figure contract.** Every figure EA shows travels with its meaning so the label cannot drift from the value (the Ageing Note's rule, generalised). A figure is: `label` (a plain word), `value`, `currency`, `basis` (net or gross of tax; cash or accrued; period to date or as of a date), `asOf`, `source` (which service), `comparison` (versus what), `quality` (flags), and `soWhat` (one line on what to do or look at, when there is something).

| ID | Requirement | MoSCoW |
|---|---|---|
| FR-INF-01 | A figure never appears without its basis and as-of date. Sales are net of VAT and labelled so; "overdue" says "older than 30 days" or "past due date" according to the source. | Must |
| FR-INF-02 | A figure never shows a number that is not true. If a source did not answer, the tile says so and every other tile renders. If two sources disagree (a sub-ledger total against the GL control total) the tile says "the Purchases ledger and the accounts differ" (`reconciles: false`), never picks silently. | Must |
| FR-INF-03 | Totals come from GL; ageing and detail come from the holder; per-customer and per-supplier detail never enters the dashboard response, only a link. | Must |
| FR-INF-04 | Every figure carries a **frame of reference**: previous period, the same period last year, or a threshold the Owner set. A single reading with no comparison is not shown as a headline. [R1, R2] | Must |
| FR-INF-05 | **Profit and cash are shown side by side, and "sold" and "collected" separately**, because the commonest mistake is reading profit as cash and unpaid invoices as income. [R1] | Must |
| FR-INF-06 | **Data-quality flags travel with the figure**: margin shown "not reliable until cost accounts are tagged" when `costOfSalesConfigured` is false; "no open period"; "ledger and sub-ledger differ"; "source unavailable". | Must |
| FR-INF-07 | **No invented thresholds.** Benchmarks in the research are vendor rules of thumb and conflict, so EA states no "healthy" level. A warning appears only when it is objective (past a due date, awaiting the Owner, a deadline within N days) or when the Owner has set the threshold (for example a minimum cash buffer). | Must |
| FR-INF-08 | `soWhat` lines are rule-based and factual ("3 invoices are more than 30 days old, the oldest from Mr X"), never advice on a decision. | Should |
| FR-INF-09 | An "Attention" list is the first thing shown: approvals, things due within a stated window, overdue items, verification, with a count and a deep link into the owning service. | Must |
| FR-INF-10 | A **statutory calendar** shows the next due filings and payments per jurisdiction, from reference data Femi confirms; amounts appear only where a service holds them. | Should |
| FR-INF-11 | Money in the Company's own currency only; more than one currency means the tile says so and sums nothing (existing R7). | Must |

**Non-functional**

| ID | Requirement |
|---|---|
| NFR-INF-01 | Owner-Admin only; the signed-in person's own token is forwarded; EA stores no copy of any business figure. |
| NFR-INF-02 | Phone check applies (see the Payroll and Personnel SPUTOs): one screen, no wide tables, notifications carry no figures or names, online only. |
| NFR-INF-03 | A cold open of the home screen may take about 3 seconds (Femi's accepted target, 2026-10-15); slow tiles load after the first paint. |
| NFR-INF-04 | Each new field is declared by the consumer (WEB) before EA ships it, and each mirror of a service's response is strict, with golden contract files. |
| NFR-INF-05 | Nothing in the Owner view lets an operator or Prodeo read business data: it is the Owner's own view of the Owner's own business. |

**A thin owner contract from each service [proposed].** Today EA calls many general-purpose routes, several of them heavy or per-item. The microservices principle says services integrate through thin interfaces. Proposal: each of SOP, IM, POP, PAY and HR offers one small, Company-scoped, read-only **owner summary** route returning a fixed handful of honest figures in the shape above (the Ageing Note's two ageing summaries are the first instances). GL keeps its existing aggregate routes. EA then makes about six calls per Company instead of dozens. Each service decides its own shape; EA mirrors it strictly. This is a proposal for each service's own session, not a requirement imposed on them.

---

## 6. Market realities that change what the Owner must see [R3, thin, partly unverified]

- **Sierra Leone.** Only about a quarter of adults had a bank or mobile money account in 2019 (secondary source); Orange Money and Africell's Afrimoney operate; power cuts cost registered firms a reported 11.2% of revenue (a secondary summary); inflation and the leone rate move; the rains raise prices and cut road access. No source quantifies informal customer credit, supplier terms or cash handling: those are **hypotheses to test with owners**, not facts.
- **Questions an owner here asks that a Western dashboard would not answer** [R3, inferred, not from interviews]: how much is in the till, the mobile-money wallet, the bank and with my agent; did that mobile-money payment arrive and what did cashing it out cost; can I afford to restock before the rains; what did generator fuel cost this month; what is my real margin if the leone moves; who owes me on credit and should I stop serving them; how much have I taken out for the family. **The system today has no cash-by-wallet view, no mobile-money reconciliation, and no fuel or power cost category beyond whatever accounts the owner creates.** These are product gaps for Femi to rank, not engineering tasks.
- **School owners** need fees owed by pupil, class and term, enrolment, staff pay and supplier bills; fees bill through SOP, but pupil-level arrears live in the Education Runtime, which is outside this pass.
- **Statutory rhythm.** NASSIT is due on or before the 15th of the following month at 15% of covered pay (5% employee, 10% employer) per NASSIT's own pages. GST, PAYE and small-taxpayer dates for Sierra Leone are **unverified** (secondary sources only; the National Revenue Authority site could not be read). UK and Irish dates were taken from GOV.UK and Revenue.ie pages (PAYE/NIC by the 22nd; VAT one month and 7 days after the period; Irish VAT3 by the 19th or 23rd by ROS) but two Irish Revenue documents conflict and **no date here is to be built into a calendar until Femi confirms it**.
- **The phone.** The researcher suggests offline capture and background sync because of data cost, power and connectivity. That is reasoning, not sourced, and **conflicts with Femi's 2026-10-15 decision (online only, nothing persisted on the phone).** I do not act on it; it is put to Femi in section 9.

---

## 7. The Owner view, layered [proposed]

| Layer | What it shows | Sources |
|---|---|---|
| **1. Needs you** (always first) | decisions waiting, things due soon, anything overdue, verification | approvals queue (extended with POP orders and HR/PAY items), due dates from POP and PAY, GL cash |
| **2. Cash and money owed** | cash now and its trend; owed to me and I owe, with the age and the basis | GL cash and control totals; SOP and POP ageing |
| **3. Sales and profit** | sales (net) with a comparison; profit and margin with a quality flag | SOP, GL |
| **4. Stock** | value; running low | IM |
| **5. People and payroll** | headcount, payroll cost, next pay, amounts owed to the authorities | HR/Personnel, PAY |
| **6. Tax and calendar** | next filings and payments | tax reference data, PAY, GL |

Layer 1 is the phone's home screen; the rest are one tap down. This extends the existing four-phase Dashboard Playbook (attention, owed, next due, cash) without replacing it.

---

## 8. Tasks (T) and order (O)

| # | Item | Owner | Depends on |
|---|---|---|---|
| **Wave 0: decisions and confirmations** | | | |
| 0.1 | Femi's answers to section 9 | Femi, via CM | none |
| 0.2 | Femi confirms the statutory dates to be used per jurisdiction (NASSIT, GST, PAYE, VAT, UK, Ireland) | Femi | none |
| 0.3 | GL's READ-without-module gap: decide and fix or accept | CM, GL | none |
| **Wave 1: no new service work** | | | |
| 1.1 | Honest-figure contract: define the shape (`basis`, `asOf`, `source`, `comparison`, `quality`, `soWhat`) in the dashboard response, declared by WEB first | EA, WEB | 0.1 |
| 1.2 | Use what exists: add `cash-books` (cash by account), `bank-reconciliations` status and POP `pending-action` to the Owner view; GL tagging-quality flag on the margin | EA, WEB | 1.1 |
| 1.3 | Attention list extended to POP purchase orders awaiting approval | EA, WEB | 1.1 |
| **Wave 2: ask each service for its owner summary** | | | |
| 2.1 | POP and SOP ageing summaries (shape in the Ageing Note) | POP, SOP | none |
| 2.2 | IM: one company-wide low-stock list and stock value total | IM | none |
| 2.3 | HR/Personnel: company-wide pending leave, advances and claims; headcount by division once division exists | HR | division recorded |
| 2.4 | PAY: next pay run, payroll cost per period, amounts owed to the authorities with due dates | PAY | the Payroll subledger (Move 2) |
| 2.5 | A comparison source: previous-period and same-period-last-year figures for sales and profit (GL or per-service) | GL, SOP | decision on where history lives |
| **Wave 3: use them** | | | |
| 3.1 | EA mirrors each summary strictly with golden contract files and maps it into the contract | EA | Wave 2, consumer first |
| 3.2 | Statutory calendar tile | EA, WEB | 0.2, 2.4 |
| **Wave 4: ranked by Femi** | | | |
| 4.1 | Cash by wallet and mobile-money reconciliation; power and fuel cost category; credit-customer controls; budget and plan | various | Femi's ranking |

**Critical path:** 0.1, 1.1, then the service summaries in parallel, then 3.1. Waves 1 and 2 do not depend on each other.

---

## 9. Decisions asked of Femi

1. **Honest-figure contract:** approve the rule that every figure carries basis, as-of, source, comparison and quality, and that EA shows no "healthy" thresholds of its own (only objective warnings and Owner-set ones)?
2. **Thresholds the Owner may set:** a minimum cash buffer (for example "warn me when cash would cover fewer than N days") and a days-late limit for chasing customers? (Recommended: yes, both Owner-set, none by default.)
3. **Thin owner summaries:** may EA ask SOP, IM, POP, PAY and HR for one small owner-summary route each, shape decided by each service?
4. **Comparisons:** where should history live so "versus last month" works: each service, or GL snapshots? (EA stores no figures.)
5. **Statutory calendar:** confirm the dates per jurisdiction (section 6) or tell me where they come from.
6. **Low-connectivity markets:** keep the app online only (your 2026-10-15 decision) for Sierra Leone as well, or allow a read-only last-seen view? (I assume online only.)
7. **Ranking of the market-specific gaps** in 4.1 (cash by wallet, mobile-money reconciliation, power cost, budget).
8. **GL's read-without-module gap** (0.3): fix now? (Recommended.)

---

## 10. What I could not verify

- Any benchmark. All come from vendors and conflict; the research found no authoritative one.
- Which dashboard tiles owners act on or ignore; no study found.
- Sage's and freee's home screens; Xero Go; Kippa's official home screen.
- Sierra Leone: informal credit, supplier terms, cash handling, mobile-money fees, current data prices, PAYE and GST due dates, small-taxpayer rules. Irish Corporation Tax and company filing dates; Northern Ireland-specific wording.
- The route inventory is from reading master, not from calling the services. Performance claims ("loads every entry") come from the code, not from timing. Facility headroom persistence is unconfirmed. How HR_ENFORCE_PAY_SPLIT is set in production is not verified.
- Whether any production Company actually has an open Period, tagged cost accounts, or both.
