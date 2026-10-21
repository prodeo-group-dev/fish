# Multi-Entity Accounting: foreign currency across Departments, Branches and Subsidiaries (Playbook, SPUTO)

**Status: DRAFT for Femi, 2026-10-22. Docs only. Nothing here is built, changed or deployed, and no policy question is decided.** Opened by the Tax Jurisdiction session (Tx) on Femi's instruction, given in pieces on 2026-10-22:

- On PQ-21 of the Tax and Currency Jurisdictions playbook: *"That is dealing with multi currency within a general ledger. We will be dealing with Departmental Accounts, Branch Accounting or Consolidated Accounts. That requires a SPUTO by you to create a Playbook to build those features. Send out researchers to get you the information on how that can be built."*
- *"You will need to collaborate with the GL and CBB on this. He needs to do the GL side, CBB also will deal with the CBB side and you the Tax side."*
- *"This is where we create a matrix to cross tab the requirements of Foreign Currency transactions in a GL that has Departments and Branches and Subsidiaries. That requires a FULL SPUTO driven Playbook."*
- *"Scope defines the Problem."* (Section 2 opens with the problem.)
- *"Coordinate and Collaborate with WEB and CM and GL and CBB over this."*

**Who writes what.** This file is one document with several owners, so each owner edits only their own cells and rows (marked in the Owner columns). Tx writes the skeleton, the scope, the matrix frame, the use cases, the tasks, the order and the tax side. **GL** confirms and completes the ledger side. **CBB** (backend owner = the GL session until a CBB backend session exists, CM, 2026-10-22) confirms the cash and bank side. **FiSH+ER WEB** writes the front-end section from the needs in section 11 (all WEB traffic goes through it, Femi's rule). **CM** routes, reviews, pushes and deploys; CM alone pushes. Anything in a GL or CBB cell is **Tx's proposal for them to confirm or correct**, drawn from the research and the repository survey, not their decision.

**Evidence.** `docs/Multi_Entity_Accounting_Research_Digest.md` (same commit set) holds the researched facts with every source labelled primary or secondary, the repository survey, and where the sources disagree. IAS 21 and IFRS 10 paragraph numbers are **unconfirmed against the licensed text** (the IFRS site is subscription-gated); no requirement below should cite a paragraph until that is checked (task T-ME-04).

## Contents (the six parts of a Playbook, `docs/Playbook_Definition.md`)

| Part | Where |
|---|---|
| 1. Operator view (what the system does TODAY, what is not built) | section 1; the Omniview operator sheet for this area: **not written** |
| 2. Scope (S) | section 2 |
| 3. Plan / SRS (P) | section 3 (numbered requirements), section 4 (the matrix), section 5 (data model and contracts sketch) |
| 4. Use cases (U) | section 6 |
| 5. Tasks (T) | section 9 |
| 6. Order (O) | section 10 |
| Policy questions for Femi | section 7 |
| Parked, conflicting, unsourced | section 8 |
| WEB's half (needs only) | section 11 |
| Collaboration status | section 12 |
| Evidence and what was not verified | section 13 |

## 1. What exists today (verified 2026-10-22, from the repository survey in the digest, section 4)

| Area | State today |
|---|---|
| Money | `Money(amount, currency)`, minor-unit rounding, refuses to add two currencies. Zero-decimal currencies (GNF, XOF) untested. |
| Account | **No currency field.** |
| Journal line | `amount: Money`, side, dimension tags (opaque strings). **No foreign amount, foreign currency or rate column.** Each currency must balance on its own inside an entry. **Nothing stops a line in a currency other than the Company's from being posted**; every report is built in the Company's base currency and would throw on it. |
| Company | One `baseCurrency`, set from its tax jurisdiction (UK GBP, IE EUR, NG NGN, SL/LR/GN/CI SLE). `fiscalYearStartMonth` stored but unused. **No parent, subsidiary or group field.** |
| FX | `FXRate` value object, not stored. `RecordFXRevaluationUseCase` revalues ONE receivable from a caller-supplied rate, a caller-supplied "currently recorded home value" and a caller-supplied FX gain/loss account id; no route reaches it. **No rate table, no rate source, no FX or rounding account in any chart template, no realised-gain calculation.** New codes reach existing Companies by adding them to the template and calling `POST /companies/{id}/standard-accounts` (the same path that delivered 5510 and 4930; proven live). (GL review, 2026-10-22.) |
| Dimensions | `DimensionType` has COST_CENTER, DEPARTMENT, PROJECT, LOCATION, PRODUCT_LINE and others; **no BRANCH, no LEGAL_ENTITY**. GL **does** write some tags today: CUSTOMER and VENDOR (AR/AP ageing), ITEM, VAT_CATEGORY, VAT_DIRECTION, CASH_FLOW_ACTIVITY (settlement lines) and PAYROLL_ELEMENT (payroll journal). **Nothing writes** DEPARTMENT, COST_CENTER, PROJECT, LOCATION or PRODUCT_LINE; values are opaque strings on `JournalLine`, not references to a master; no validation; none mandatory; **only AR/AP ageing reads a dimension, and no report groups the profit and loss by any.** (GL review, 2026-10-22.) |
| Groups | A Tenant owns Companies (Purse: four) but **nothing links them financially.** No parent, group currency, intercompany tag, elimination, translation or consolidated report. UC-CFO5 / FR-CFO07 (consolidation as a reporting layer) are documented and unbuilt. UC-HR12 (payroll recharge) is prose only. |
| Cash and bank | One currency per book today (the Company's); WEB-CBB reports that every book carries its own currency from the CBB list, that the Accounts list captions "Amounts in {first book's currency}", that the in/out forms send only an amount (no currency, no rate), that reconciliation runs in the chosen account's own currency, and that **CBB refuses a statement whose currency is not the Company's base (`currency_mismatch`), so a foreign statement cannot start today.** No foreign-currency UI exists or is designed. GL's Phase 2a IAS 21 design for foreign-currency books is **design only, with eight open questions for Femi, all unanswered.** It excludes subsidiary translation and foreign customers and suppliers. |
| Other services | Foreign-currency sales, purchases and payroll are **not possible.** SOP refuses a line currency other than the Company's; POP does not (no such check found); IM does not tie item currency to the Company; HR/Payroll's currency check (T-TJ-09, D-1) is now built and committed locally in fish-payroll (d4f0fe0; 409 `currency_mismatch`, 503 `company_currency_unavailable`; fixtures on `fish-contracts` branch `payroll-currency-mismatch` 8337bf3), with CM holding the tip, not yet deployed. |
| Decided already | Company currency from tax jurisdiction; Payroll currency = GL currency; pay in the PAYE jurisdiction's currency; no hard-coded currency; SLE-only onboarding across the Mano River operation; consolidation is a reporting-layer operation that never merges ledgers; per-Company RBAC is frozen until Live. **Nothing is decided on departments, branches, consolidation scope or Purse's structure.** |

**Not built (this area):** foreign amounts on lines; account currency; exchange-rate table and sources; realised and unrealised FX posting; FX accounts; revaluation route; presentation-currency translation and translation reserve; department, cost-centre and location master lists, validation and reports; a BRANCH dimension; inter-branch accounts; parent Company, group currency, group mapping, intercompany tag and reconciliation, eliminations, consolidated reports; foreign-currency cash and bank books; foreign-currency sales, purchases and payroll; every tax rule that depends on currency (section 3.9). Not deployed or not exercised: I did not check production.

## 2. Scope (S)

### 2.1 The problem

A FiSH Tenant that is more than one site in one currency cannot be kept properly in FiSH today.

1. **It cannot hold a foreign-currency amount.** A Company has one currency, an account has none, and a journal line holds only a base-currency amount. There is no exchange-rate table, no realised or unrealised exchange gain or loss, and no FX account in any chart. An invoice to a customer in dollars, a euro supplier, a dollar bank account, or a person paid under another country's PAYE has nowhere to live. The only FX code revalues one receivable on a caller-supplied rate and no route reaches it. Worse, nothing stops a foreign-currency line being posted to a Company ledger, and then every report throws.
2. **It cannot tell departments or branches apart.** The tags exist (Department, Cost Center, Location) but nothing writes them, nothing checks them, no report groups by them, and there is no Branch at all. An owner cannot ask how the Lagos branch did, or what the workshop costs.
3. **It cannot see a group.** A Tenant can own several Companies (Purse: GBP, EUR and SLE) but nothing links them: no parent, no group currency, no intercompany marker, no translation, no eliminations. Every group view is a spreadsheet, and a recharge between two group entities is counted twice.
4. **The three needs are one problem.** A foreign branch needs translation and a local tax registration. A subsidiary in another country needs all three. Payroll for a person taxed under another country's PAYE needs a currency, a department or branch tag and an intercompany recharge. Solving them separately would produce three models that do not fit together.

**Who is hurt.** The Business Owner with a second site, an overseas customer or supplier, or a subsidiary. The accountant and tax professional preparing accounts and tax. Purse, the first group. Every service that posts (SOP, POP, IM, HR/Payroll, CBB), which today refuses or misrepresents anything outside the Company's currency.

**What it costs to leave it.** FiSH's duty is accurate preparation (Decisions Log, 2026-10-16); wrong, impossible or spreadsheet-only foreign-currency and group figures break that duty and the trust it earns, and push Tenants back to side spreadsheets. A foreign-currency line slipping into a base-currency ledger is a silent integrity risk.

### 2.2 In scope
The requirements of foreign-currency transactions in a general ledger, **cross-tabulated against three organisational shapes**: Departments (inside one Company), Branches (one legal entity in more than one place, including a branch abroad), and Subsidiaries (separate Companies in a group, in the same or another currency). That covers: recording and settling foreign amounts, exchange rates and their sources, revaluation, foreign cash and bank, dimension tagging and departmental reporting, branch and inter-branch accounting, parent and subsidiary links, intercompany, translation, consolidation, the tax effects, and the matching screens and controls.

### 2.3 Out of scope for this playbook
Hedging and derivatives; hyperinflation restatement (IAS 29), kept as a watch item; non-controlling interests, goodwill, the equity method and consolidated cash flow in version one (deferred, not forgotten); statutory consolidated accounts (until Femi decides who needs them, section 7); filing integrations; per-department or per-branch access control (RBAC is frozen until Live); stock at invoice price with unrealised-profit loading; foreign-currency sales and purchases as documents (a later SPUTO that reuses this model, as GL's Phase 2a also says).

### 2.4 Boundaries between the owners
| Part | Owner | Covers |
|---|---|---|
| Ledger | GL | foreign amounts and rates on lines, rate table, revaluation and realised FX, FX accounts, dimensions and departmental reports, branch and inter-branch accounts, parent link, intercompany tag, consolidation run |
| Cash and bank | CBB (GL session for now) | foreign-currency cash and bank books, reconciliation in a foreign currency, transfers between books and branches, the FX line of the cash-flow statement |
| Tax | Tx | tax jurisdiction per entity, VAT on foreign-currency supplies, tax computation currency, branch registration, PAYE across jurisdictions, group tax and recharges |
| Services | SOP, POP, IM, HR/Payroll | pass tags and currencies, refuse what they cannot yet handle, foreign-currency documents later |
| Front end | FiSH+ER WEB | screens, from section 11 |
| Operations | CM | review, push, deploy |

### 2.5 Principles that bind this work (decisions already taken)
| # | Principle | Source |
|---|---|---|
| M1 | Femi decides policy; this document recommends and never decides; no invented holds. | Decisions Log 2026-10-16 |
| M2 | One ledger per legal entity; consolidation is a reporting-layer operation that never merges or alters any entity's ledger. | UC-CFO5, FR-CFO07; CLAUDE.md |
| M3 | A Company has one base currency, set from its tax jurisdiction; screens and Payroll take it from the Company, never a literal. | Decisions Log 2026-10-22 |
| M4 | Payroll currency = GL currency; pay is in the currency of the tax jurisdiction over the pay; pay terms Owner Admin only. | Decisions Log 2026-10-22 |
| M5 | Money never mixes currencies; a report states its currency and never sums mixed currencies. | `Money`; WEB rule |
| M6 | Fail closed: refuse with a plain message rather than default or guess a rate. | Decisions Log 2026-10-14 |
| M7 | Accurate preparation is FiSH's duty; the records are the Tenant's; FiSH does not audit. Consolidated output must not be presented as statutory accounts unless that is confirmed. | Decisions Log 2026-10-16 |
| M8 | One owner per kind of data; narrow, versioned, consumer-first contracts with fixtures; strict decoding; additive and nullable changes. | Decisions Log 2026-10-18; CLAUDE.md |
| M9 | Foundations before features: audit, idempotency and period locks before anything that moves money. | Femi 2026-10-07 |
| M10 | Prodeo is a landlord: rates and mappings are platform reference data, not a view into Tenant data. | Decisions Log 2026-10-15 |
| M11 | SLE is the only currency onboarded across the Mano River operation; this limits which currencies are onboarded, not the ledger design. | Decisions Log 2026-08-22, 2026-10-22 |

### 2.6 Glossary
**Functional (base) currency:** the Company's currency of record, set from its tax jurisdiction. **Transaction currency:** the currency a document is in. **Presentation (group) currency:** the currency a group or consolidated report is shown in. **Company:** one legal entity with its own ledger (the Organisation, in Femi's word). **Tenant:** the owner of one or more Companies. **Department:** a unit inside a Company used for responsibility and cost reporting. **Branch:** a place of business of the same legal entity, here by default a dimension of the Company; a foreign branch with its own currency or tax registration is the documented exception (set up as a Company). **Subsidiary:** a Company controlled by another Company. **Group:** a parent Company and its subsidiaries within a Tenant. **Intercompany:** a transaction or balance between two Companies of one group. **Translation reserve (CTA):** the equity line that makes a translated trial balance balance. **Realised / unrealised exchange difference:** system labels for the difference at settlement versus on retranslating an open item at period end (not IAS 21 terms).

## 3. Plan / SRS (P): requirements

Priority: **M** must, **S** should, **C** could. Today: **Built**, **Partial**, **No**. **Owner** is who confirms and completes the row. IDs are stable; tasks and use cases cite them.

### 3.1 Foreign amounts in the ledger (ME-FX), owner GL
| ID | Requirement | Pri | Today |
|---|---|---|---|
| ME-FX-1 | A journal line can carry a foreign amount, a foreign currency and the rate used, beside the base-currency amount; the base amount stays the amount every report sums (GL Phase 2a option C; the choice between A, B and C is Femi's, PQ-M1). | M | No |
| ME-FX-2 | A Company reports only in its base currency; foreign amounts appear only beside their currency; no report sums mixed currencies. | M | Partial (base only; foreign cannot exist) |
| ME-FX-3 | A line whose currency is not the Company's is refused unless it carries the foreign-amount fields and sits on an account allowed to be foreign; otherwise a plain 409. **This closes today's silent gap and can ship before any FX feature.** GL's proposed shape: one shared guard used by `PostJournalEntryUseCase` and every Record* use case (sale, obligation, payment, collection, credit note, receipt and issue, payroll, pay-run journal, cash book), refusing with 409 `currency_not_company_currency` and a plain-words detail naming the line and both currencies; about 1.5 GL days with tests; additive, no migration. **Before it ships, someone runs a read-only production count of journal lines whose currency differs from their Company's base currency**; any that exist are test data to be reviewed, not silently refused later. Today `PostJournalEntryUseCase` has no currency check and the route accepts any ISO currency per line. | M | No |
| ME-FX-4 | An account may have a currency (nullable). Version one: cash and bank assets (Phase 2a); later receivable and payable control accounts per customer or supplier. | M | No |
| ME-FX-5 | A foreign-currency transaction is recorded at the spot rate on the transaction date (a documented average-rate shortcut is allowed only where rates barely move); the rate and its source are stored on the line. | M | No |
| ME-FX-6 | Monetary items (cash, bank, receivables, payables) are retranslated at the closing rate at each reporting date through an explicit "revalue as at date" action; the difference goes to profit or loss. Non-monetary items (stock, fixed assets at cost) keep the transaction-date rate. | M | No |
| ME-FX-7 | A realised exchange difference is computed at settlement and posted to a dedicated FX account; an unrealised one on revaluation to a separate account (or the same account, Femi's choice, Phase 2a Q4). Both are in profit or loss. | M | No |
| ME-FX-8 | Converting an entry line by line can leave it out of balance by minor units: the difference posts automatically to a per-currency rounding account, separate from FX gain or loss, under a threshold so real errors are not absorbed. | S | No |
| ME-FX-9 | Revaluation entries are dated and auditable; whether they auto-reverse is a decision (Phase 2a Q5); reopening a period requires rerunning every later closed period. | S | No |
| ME-FX-10 | Hyperinflation restatement (IAS 29) is out of scope; the registry may record a watch status per jurisdiction (the researchers: Sierra Leone ceased to be hyperinflationary by 31 March 2026; Nigeria not hyperinflationary but monitored). | C | No |

### 3.2 Exchange rates (ME-RATE), owner GL, with Tx on sources
| ID | Requirement | Pri | Today |
|---|---|---|---|
| ME-RATE-1 | A rate table: from, to, rate, as-of date, rate type (spot, closing, average, historical), source, entered by, entered at, manual-override flag and reason. A rate is never overwritten; a correction is a new row. Lookup is "latest on or before". | M | No |
| ME-RATE-2 | Every rate has a recorded source. Documented sources: ECB and Bank of England for EUR, GBP, USD (feeds exist; reuse terms noted in the digest); Central Bank of Nigeria NFEM for NGN (no confirmed feed); Bank of Sierra Leone indicative rate for SLE (daily PDFs, no confirmed feed). **Neither the Bank of England nor the ECB publishes NGN or SLE**, so version one is manual entry with the source recorded. | M | No |
| ME-RATE-3 | Each posted line stores the rate it used (and which rate row), so history never changes when a later rate is entered. | M | No |
| ME-RATE-4 | Nigeria has an official and a parallel rate; the platform records which series was used and does not choose between them silently. Which to book is Femi's call (PQ-M5). | M | No |
| ME-RATE-5 | Rate entry and change is an audited operator or accountant act (the same platform change log as the rulebook, TJ-GOV-2). | M | No |
| ME-RATE-6 | Rate types average, closing and historical are used for translation (ME-GRP-5) and only needed when translation is built. | S | No |
| ME-RATE-7 | Automatic feed import (ECB, Bank of England) is optional and deferred; it must keep the source and licence terms. | C | No |
| ME-RATE-8 | Scope of the rate table (platform-wide, per Tenant, per Company) is a decision; consolidation needs every entity of a group to use the same rates for the same date (PQ-M5). GL's recommendation: one platform-wide table owned by GL (rates are facts, not Tenant data), with Tenant or Company overrides recorded as override rows with a reason, never overwriting. | M | No |

### 3.3 Departments and other dimensions (ME-DEP), owner GL
| ID | Requirement | Pri | Today |
|---|---|---|---|
| ME-DEP-1 | A Company has a master list per dimension type (department, cost centre, location, project): code, name, active. Values are archived, not deleted, so past reports are preserved. | M | No |
| ME-DEP-2 | A line's dimension values are validated against the master list; an unknown value is refused. | M | No |
| ME-DEP-3 | A per-account rule says a dimension is REQUIRED, OPTIONAL or FORBIDDEN (the Odoo and Dynamics pattern); a posting missing a REQUIRED value fails. The default is OPTIONAL: nothing becomes mandatory without the owner choosing it. | S | No |
| ME-DEP-4 | Every dimension report shows an explicit **Unassigned** row, and the report's total equals the ledger total (a check, not a hope). | M | No |
| ME-DEP-5 | Profit and loss by department, cost centre, location or project. **A balance sheet by department is not version one** (it needs a balancing segment; no vendor gives it for free). | M | No |
| ME-DEP-6 | Shared-cost allocation: an optional allocation run (direct method; bases headcount, floor area, revenue) posts dated journals tagged to departments. Step-down and reciprocal methods are deferred. | C | No |
| ME-DEP-7 | Services pass department or location tags where their document carries them (Payroll first: the employee's department on pay lines; POP expenses next); defaults come from the item or employee. HR reports that Payroll's run posting is GL's totals call (wages total, salaries total, three accounts) with no department, branch or cost-centre tag, that the only tag a Payroll line carries is EMPLOYEE (advances, claims), and that **HR's employee record has no department or branch field**: HR must own a department or branch per person first. The split is then a clean fit for GL's agreed per-line pay-run journal (per-line account plus an opaque tag); add the dimensions there, not as a separate posting (see also the Move 2 subledger note). | S | No (no service sends any) |
| ME-DEP-8 | Renaming or merging a department: version one archives and adds; no restatement of past reports (no source exists for restating; Femi to confirm, PQ-M7). | C | No |

### 3.4 Branches (ME-BR), owner GL, EA for the Company-as-branch exception
| ID | Requirement | Pri | Today |
|---|---|---|---|
| ME-BR-1 | **Default:** a branch is a dimension value inside one Company (one ledger, one currency, one tax registration). A BRANCH dimension type is added (or LOCATION is reused, PQ-M2). | M | No |
| ME-BR-2 | **Exception:** a foreign branch that needs its own currency or its own tax registration is set up as a Company linked to its parent, with the intercompany rules of section 3.6. | M | No |
| ME-BR-3 | Inter-branch transfers of cash or stock inside one Company are one entry with two branch tags, balanced per entry; there are no separate inter-branch ledgers. Branch-as-Company transfers use intercompany accounts (ME-IC). | S | No |
| ME-BR-4 | Stock transferred to a branch at invoice price, with an unrealised-profit reserve, is out of version one. | C | No |
| ME-BR-5 | A branch report (profit and loss by branch) and a branch cash view use the same scope control as departments. | M | No |

### 3.5 Groups and consolidation (ME-GRP), owner GL, EA for the Tenant side
| ID | Requirement | Pri | Today |
|---|---|---|---|
| ME-GRP-1 | A Company may have a parent Company in the same Tenant (with ownership percentage and from and to dates; version one is control at 100%). A group has a presentation currency. Purse's real structure must be settled first (PQ-M4). | M | No |
| ME-GRP-2 | Consolidation is a reporting-layer operation: it never changes any Company's ledger. | M | Decided |
| ME-GRP-3 | A consolidation run takes each entity's closed-period trial balance, maps each entity's accounts to a group chart (a mapping table), translates to the group currency, eliminates intercompany, and produces a consolidated trial balance, balance sheet and income statement with drill-back to each entity. | M | No |
| ME-GRP-4 | A run is **persisted with its frozen inputs** (rates, mapping version, source trial-balance identifiers, parameters, who and when) so it reproduces exactly. Elimination and adjustment journals live in a consolidation scope, never in a Company ledger. (A pure on-demand report has no record of the rates used; a pure consolidation ledger risks stale data after a source change; this hybrid is Tx's recommendation, PQ-M6.) | M | No |
| ME-GRP-5 | Translation: assets and liabilities at the closing rate, income and expenses at the average (or transaction) rate, equity at historical rates; the difference goes to a translation reserve line that makes the translated trial balance balance. Paragraphs to be confirmed (T-ME-04). | M | No |
| ME-GRP-6 | An intercompany monetary item in different currencies cannot be eliminated without leaving its exchange difference visible. The treatment must follow IAS 21 and be confirmed against the licensed text; **the vendor behaviour (NetSuite puts the residual in a CTA account) must not be copied unchecked** (digest section 5). | M | No |
| ME-GRP-7 | Entities in one run share a reporting date; if they differ, a run refuses (IFRS 10 permits up to a three-month gap, which is deferred). | S | No |
| ME-GRP-8 | Non-controlling interest, goodwill, the equity method, consolidated cash flow, unrealised profit in stock and multi-level hierarchies are deferred. | C | No |
| ME-GRP-9 | Every consolidated output is labelled **management consolidation** unless the framework and the entities are confirmed for statutory use and Femi says so. | M | No |
| ME-GRP-10 | Version-one demand: most small UK and Irish groups are legally exempt (a small group), so the driver is management, lender and investor reporting and medium groups; statutory scope is Femi's decision (PQ-M4). | M | n/a |

### 3.6 Intercompany and inter-unit (ME-IC), owner GL, HR for the recharge
| ID | Requirement | Pri | Today |
|---|---|---|---|
| ME-IC-1 | An intercompany line carries a counterparty tag naming the partner Company (a new dimension type; the identifier is the partner's Company id). | M | No |
| ME-IC-2 | Intercompany balances sit in dedicated due-to and due-from accounts per partner, and each Company posts **its own side** (two entries, never one entry across two ledgers). | M | No |
| ME-IC-3 | An intercompany reconciliation report lists unmatched and mismatched items (amount, currency, date, items in transit) before consolidation. | M | No |
| ME-IC-4 | A payroll recharge between group entities is a separate, explicit intercompany journal, never embedded in the payroll posting (UC-HR12 as written). HR: **designed, not built** (`HR_Payroll_DDD_Design` section 8.1); it needs a counterparty Company tag or an intercompany account pair on both sides' lines and an elimination at consolidation, and an employee mapped to one Company or an apportioned set (UC-HR1; today an employee belongs to exactly one Company). | M | No |
| ME-IC-5 | Intercompany sales and purchases treat the other Company as a customer or supplier and tag the document as intercompany; VAT applies between separate legal entities (ME-TAX). | S | No |
| ME-IC-6 | Timing differences in transit (cash, goods) are visible and expire or reverse by a rule, not by a manual fix. | S | No |

### 3.7 Cash and bank (ME-CASH), owner CBB (GL session for now)
| ID | Requirement | Pri | Today |
|---|---|---|---|
| ME-CASH-1 | A Company may open cash and bank books in currencies other than its own, from a curated list (Phase 2a Q1: GBP, EUR, USD, NGN, SLE recommended; LRD, GNF, XOF not onboarded). | M | No |
| ME-CASH-2 | Receipts, payments and transfers on a foreign book carry the foreign amount and the rate; a transfer between books in different currencies posts the realised difference. | M | No |
| ME-CASH-3 | Reconciling a foreign statement is done in the book's currency; the base-currency carrying value is reconciled by revaluation (ME-FX-6), not by statement matching. | M | No |
| ME-CASH-4 | In the cash-flow statement, the effect of exchange-rate changes on foreign cash is its own reconciling line, not an operating, investing or financing flow (IAS 7, as Phase 2a states). | M | No |
| ME-CASH-5 | A cash book can be viewed by branch tag; cross-currency inter-branch transfers use ME-FX. | S | No |
| ME-CASH-6 | A document's "Paid into" choice shows each book's currency, and a foreign book cannot be picked for a document in the Company's currency unless the conversion is explicit (WEB-CBB: today the picker shows no currency, so a USD book could be picked for a GBP invoice). | M | No |
| ME-CASH-7 | Money in, money out and move money accept and record the foreign amount, the rate and the base amount; a transfer needs the amount and the rate on both sides; the book table shows a base-currency column, the rate, and a running balance in the book's currency plus per-currency totals; the Accounts list shows no total across currencies; CSV export carries the rate and base columns; the idempotency attempt-key fingerprint includes the rate. | M | No |
| ME-CASH-8 | Reconciliation decisions that foreign currency changes (WEB-CBB, all waiting on Phase 2a and the SRS 9.7 answers): the statement currency is the account's currency; tie-out is in the account currency; whether to show account and base amounts together; the realised exchange difference on a matched line appears as a separate adjustment (SRS); whether foreign reconciliation is in the MVP is Femi's. | M | No |

### 3.8 Other services (ME-SVC)
| ID | Requirement | Pri | Owner | Today |
|---|---|---|---|---|
| ME-SVC-1 | SOP and POP refuse a line currency other than the Company's until foreign-currency documents are designed (a later SPUTO reusing this model). POP does not yet check this (T-TJ-27). | M | SOP, POP | Partial |
| ME-SVC-2 | IM ties item currency to the Company's; stock is a non-monetary item valued at the transaction-date rate. | S | IM | No |
| ME-SVC-3 | HR/Payroll pay currency equals the Company's (decided, built locally). A person taxed under another PAYE jurisdiction is **not** handled by a foreign-currency pay run: by the recommendation in PQ-M10 that person is employed by a Company (branch or subsidiary) in that jurisdiction. HR/Payroll today has **no per-person work country or tax jurisdiction**: only the Company's (`employee.companyId`); `PayrollTaxRule` has a jurisdiction string but nothing links an employee to a rule. Allowing a different currency per person would mean relaxing the just-built refusal on purpose (PQ-M10 option b). | M | HR/Payroll | Partial |
| ME-SVC-4 | Fixed assets are non-monetary: a foreign-currency purchase price is converted once at the transaction date and not retranslated. | S | GL (fixed assets) | n/a |
| ME-SVC-5 | Services that carry department or location tags (ME-DEP-7) send them in strict, versioned DTOs declared by the receiving side first. | S | all | No |

### 3.9 Tax (ME-TAX), owner Tx
| ID | Requirement | Pri | Today |
|---|---|---|---|
| ME-TAX-1 | Every Company has exactly one tax jurisdiction; a branch set up as a Company has its own; a branch that is a dimension is under its Company's. | M | Built (Company) |
| ME-TAX-2 | VAT on a supply invoiced in a foreign currency is computed and reported in the VAT jurisdiction's currency using the rate that jurisdiction permits at the tax point; the rate and its source are stored with the posting. **Researched so far (digest 6.1 and 6.2; Femi confirms):** UK VAT is computed in sterling using the UK market selling rate at the time of supply, or HMRC's period rate, or a rate agreed with HMRC, and the invoice must show the VAT total in sterling; Ireland requires the euro figures on a foreign-currency invoice at the Central Bank selling rate, with the date described differently by two Revenue sources (invoice due to be issued versus tax becomes due). The rate type and rate date are therefore per-jurisdiction settings, not constants. Nigeria and the Mano River countries: pending (digest 6.4). | M | No |
| ME-TAX-3 | Corporation tax is computed from the Company's functional-currency ledger; where the jurisdiction requires its own currency or rates, the conversion is a recorded step. **Researched so far (digest 6.1 and 6.2; Femi confirms):** UK corporation tax is computed and returned in sterling, with a functional-currency route (CTA 2010 sections 7 to 11) for companies whose functional currency is not sterling; Ireland returns in euro, with a section 402 functional-currency route for capital allowances and trading losses, and section 79 bringing realised and unrealised trade exchange differences into trading income. So the unrealised-versus-realised treatment is a per-jurisdiction fact. Nigeria and the Mano River countries: pending (digest 6.4). | M | No |
| ME-TAX-4 | PAYE: pay is in the currency of the tax jurisdiction over the pay (Femi D-2). A person working in a jurisdiction other than the employer Company's may need PAYE registration there; this is a permanent-establishment, branch or subsidiary question (PQ-M10). Version one does not support two PAYE jurisdictions in one payroll. | M | No |
| ME-TAX-5 | A branch abroad: whether it creates a taxable presence or needs a VAT registration is a question for Femi per jurisdiction; the registry's tax-jurisdiction-per-Company model is what a foreign branch Company uses. | M | No |
| ME-TAX-6 | Group relief (UK and Ireland both at 75%), consolidated tax returns and transfer pricing for recharges are out of version one; the UK branch exemption becomes mandatory from 1 January 2027 only if the draft clauses are enacted (digest 6.1); the basis of a recharge is stored as a document reference. | C | No |
| ME-TAX-7 | The data side of every FX-related tax rule (rate source per jurisdiction, date basis, currency of computation) lives in the rulebook of the Tax and Currency Jurisdictions playbook, not here. This playbook only names the rows. | M | n/a |

### 3.10 Reporting (ME-RPT), owner GL, WEB for the screens
| ID | Requirement | Pri | Today |
|---|---|---|---|
| ME-RPT-1 | Every report states its currency and its scope (Company, department, branch, group). | M | Partial |
| ME-RPT-2 | Reports accept an optional dimension scope (default All) and show Unassigned. | M | No |
| ME-RPT-3 | Consolidated trial balance, balance sheet and income statement in the group currency, with per-entity columns, an elimination column and drill-back. | M | No |
| ME-RPT-4 | The cash-flow statement carries the FX effect on cash line (ME-CASH-4). | M | No |
| ME-RPT-5 | Receivable and payable ageing by currency when foreign customers and suppliers exist. | S | No |

### 3.11 Governance and controls (ME-GOV), owner GL, CM
| ID | Requirement | Pri | Today |
|---|---|---|---|
| ME-GOV-1 | Rate entries, revaluations, consolidation runs, mapping changes and dimension master changes are audited: who, when, old and new, reason, source. | M | No |
| ME-GOV-2 | A per-entity period close lock precedes consolidation; a run reads closed periods only. | M | Partial (periods close; no run) |
| ME-GOV-3 | Access: version one uses the existing per-Company access; a consolidated view needs access to every Company in the group; per-department or per-branch access is an RBAC change and waits for the Live switch. | M | n/a |
| ME-GOV-4 | Revaluation and consolidation runs are idempotent per (Company, as-of) and (group, as-of, parameters). | M | No |

### 3.12 Non-functional (ME-NFR)
No mixed-currency sums in the type system; additive, nullable migrations only; strict decoding with declared-first fields; golden tests with hand-calculated figures (including rounding and a three-currency chain); consolidation computed on demand for up to ten entities; a `fish-contracts` fixture for every new read; plain-words refusals; no currency literal anywhere (Femi D-5).

## 4. The matrix: foreign-currency requirements by organisational shape

**How to read it.** Rows are the requirements of a general ledger that handles foreign-currency transactions. Columns are the five shapes a Tenant can take. Each cell says what the shape needs, in codes, so the matrix reads at a glance; the notes under it explain the cells that are not obvious. Section 4.3 gives the owner, the requirement IDs and the standard behind each row. **A cell is Tx's proposal; the GL and CBB owners confirm or correct the cells in their rows.**

**Columns**
- **Dept** = a Department (a dimension inside one Company).
- **Br-D** = a Branch in the same country and currency (a dimension of the Company).
- **Br-F** = a Branch abroad with its own currency or tax registration (the documented exception: a Company linked to its parent).
- **Sub-S** = a Subsidiary in the same currency (a separate Company).
- **Sub-F** = a Subsidiary in another currency (a separate Company).

### 4.1 Legend
| Code | Meaning |
|---|---|
| C | the Company's own rule applies; nothing special for this shape |
| T | a dimension tag on the line (validated, optionally mandatory) |
| M | memo foreign amount, foreign currency and rate on the line (option C) |
| Rt | rate-table lookup (with a stored rate type and source) |
| S | a separate ledger: this shape is its own Company |
| I | inter-unit accounts (due-to and due-from, both sides post) |
| E | eliminated at consolidation |
| X | translated into the group currency (closing, average, historical, translation reserve) |
| L | a local legal or tax registration question (Femi's) |
| D | needs a decision from Femi (section 7) |
| V | deferred past version one |
| - | not applicable |

### 4.2 Matrix A: the cross-tab
| # | Requirement | Dept | Br-D | Br-F | Sub-S | Sub-F |
|---|---|---|---|---|---|---|
| R1 | Where the books live | C, T | C, T | S, L | S | S |
| R2 | Record a foreign-currency transaction at the spot rate on its date | M Rt (against the Company's currency) | M Rt | M Rt (against the branch Company's own currency) | M Rt | M Rt (against the subsidiary's own currency) |
| R3 | Source and scope of exchange rates | C (D: table scope) | C | Rt D (shared with parent) | C | Rt D (shared across the group) |
| R4 | Realised exchange difference at settlement | C, T (D: which unit carries the FX line) | C, T (D) | C (own Company) | C | C |
| R5 | Period-end revaluation of monetary items | C, T (D) | C, T (D) | C (own Company) | C | C |
| R6 | Foreign cash and bank books | - | T (branch cash view) | S, M | S, M | S, M |
| R7 | Foreign customers and suppliers | V (later SPUTO) | V | V | V | V |
| R8 | Payroll and the PAYE currency | T (employee's department) | T (branch) | S, L (local payroll in the branch Company) | S | S, L |
| R9 | Non-monetary items (stock, fixed assets): no retranslation | C | C | X at consolidation | C | X at consolidation |
| R10 | Dimension tagging, master list, mandatory rule | T | T | T (inside its own Company) | T | T |
| R11 | Balances between units | - (allocation, not balances) | I (inter-branch, nets to zero inside the Company) | I, E | I, E | I, E, M (foreign-currency intercompany, FX residual) |
| R12 | Translation to the group currency | - | - | X | - (same currency) | X |
| R13 | Elimination at consolidation | - | - | E | E | E |
| R14 | Tax jurisdiction and registrations | C | C | L | C | L |
| R15 | VAT on a foreign-currency supply | Rt (UK: sterling VAT at the time-of-supply market rate or an agreed rate; IE: euro figures at the Central Bank selling rate) | Rt | Rt, L | Rt | Rt, L |
| R16 | Corporation tax currency of computation | C (UK sterling, IE euro; functional-currency routes exist) | C | L (branch profits: UK exemption elective, IE credit relief; branch-profit currency not found) | C | L (own jurisdiction's rule) |
| R17 | Period close and lock | C | C | C (own Company) | C | C |
| R18 | Reports available | P&L by department (V: balance sheet by department) | P&L by branch; branch cash view | entity report and consolidated | entity report and consolidated | entity report (own currency) and consolidated (group currency) |
| R19 | Audit trail of rates, runs, mappings | C | C | C | C | C |
| R20 | Access control | V (per-department waits for Live) | V (per-branch) | C (per-Company) | C (per-Company) | C (per-Company) |

### 4.3 Matrix B: owner, requirements, standard and status per row
| # | Owner | Requirement IDs | Standard or source (digest) | Status today | Femi decision |
|---|---|---|---|---|---|
| R1 | GL, EA | ME-BR-1, ME-BR-2, ME-GRP-1 | researcher 2 rule: dimension by default, Company for a foreign branch with its own currency or registration | No | PQ-M2, PQ-M3 |
| R2 | GL | ME-FX-1, -3, -5 | IAS 21 initial recognition at the spot rate (digest 1.1) | No | PQ-M1 |
| R3 | GL, Tx | ME-RATE-1, -2, -3, -4, -8 | central-bank sources and gaps (digest 1.4) | No | PQ-M5 |
| R4 | GL | ME-FX-7 | realised vs unrealised labels (digest 1.1, 1.2) | No | PQ-M1 (Phase 2a Q4) |
| R5 | GL | ME-FX-6, -9 | closing-rate retranslation; vendors differ on posting and reversal (digest 1.2) | No | Phase 2a Q5 |
| R6 | CBB (GL), GL | ME-CASH-1 to -5 | Phase 2a IAS 21 design; IAS 7 | No | Phase 2a Q1, Q2 |
| R7 | SOP, POP | ME-SVC-1 | Phase 2a excludes it | No | Phase 2a Q7 |
| R8 | HR/Payroll, Tx | ME-SVC-3, ME-TAX-4, ME-DEP-7 | Femi D-1 to D-5 (2026-10-22) | No | PQ-M10 |
| R9 | GL | ME-FX-6, ME-GRP-5 | IAS 21 monetary vs non-monetary (digest 1.1) | No | n/a |
| R10 | GL | ME-DEP-1 to -4, -7 | Odoo mandatory plan, Dynamics account structure, Xero "Unassigned" (digest 2.2, 2.3) | No | PQ-M6a |
| R11 | GL, HR | ME-BR-3, ME-IC-1 to -6 | Dynamics due-to and due-from, NetSuite intercompany (digest 2.4, 3.5) | No | PQ-M2 |
| R12 | GL | ME-GRP-5, ME-RATE-6 | IAS 21 translation (digest 3.2); NetSuite rate types | No | PQ-M7 |
| R13 | GL | ME-GRP-3, -4, -6 | IFRS 10; intragroup monetary items (digest 3.1, 3.2, section 5) | No | PQ-M6, PQ-M7 |
| R14 | Tx | ME-TAX-1, -5 | permanent establishment and VAT fixed establishment differ (digest 2.6) | Built (Company) | per jurisdiction |
| R15 | Tx | ME-TAX-2 | UK and IE researched (digest 6.1, 6.2); NG and Mano River pending | No | PQ-M13 |
| R16 | Tx | ME-TAX-3 | UK and IE researched (digest 6.1, 6.2); NG and Mano River pending | No | PQ-M13 |
| R17 | GL | ME-GOV-2 | IFRS 10 same reporting date; NetSuite elimination after close (digest 3.1, 3.6) | Partial | n/a |
| R18 | GL, WEB | ME-DEP-5, ME-BR-5, ME-RPT-1 to -5 | researcher 2: P&L by tag is easy, balance sheet by tag is not (digest 2.2) | No | PQ-M6a |
| R19 | GL, CM | ME-GOV-1, ME-RATE-5 | NetSuite audit report; Dynamics reversal history (digest 1.2, 3.4) | No | n/a |
| R20 | EA, CM | ME-GOV-3 | RBAC frozen until Live | n/a | after Live |

### 4.4 Notes on the cells that are not obvious
- **R1.** A Department and a domestic Branch share the Company's ledger, currency and tax registration; they differ only in what they are for (responsibility versus place). A foreign branch is the exception that becomes a Company because it needs its own currency or registration; once it is a Company, its row behaves like a subsidiary's (it is a controlled entity in its own jurisdiction). The rule is the researcher's suggested rule, not a decision (PQ-M2).
- **R2.** The statement "against the Company's currency" matters: a subsidiary's own foreign-currency dealings are measured against its own functional currency, not the group's. Translation to the group currency is a separate step (R12).
- **R3.** Consolidation requires every entity of a group to use the same rate for the same date and rate type; so the rate table cannot be private to a Company. Where it lives is PQ-M5.
- **R4 and R5.** For a Department or a domestic Branch the exchange difference is the Company's, but which department or branch it should be reported against (the unit that owns the settled item, or an unallocated line) changes the departmental report; this is a small decision (PQ-M6a).
- **R6.** A Department has no cash of its own; a Branch can have a branch cash view by tag; a Subsidiary's books are its own. All foreign-currency books follow Phase 2a option C.
- **R7.** Foreign customers and suppliers are deferred to a later SPUTO that reuses this model, as GL's Phase 2a states; the row is in the matrix so the later SPUTO knows the shape.
- **R8.** A person paid under another PAYE jurisdiction is the case that opened this playbook (PQ-21). Femi's D-2 ties the pay currency to the jurisdiction over the pay. The recommendation (PQ-M10) is that such a person sits on the payroll of a Company in that jurisdiction (Br-F or Sub-F), which is exactly what this matrix provides; the alternative, a foreign-currency pay run inside one Company, needs per-person jurisdiction and is not recommended for version one.
- **R9.** Stock and fixed assets keep their transaction-date rate in the entity's own books; they are translated at the closing rate only when a foreign entity's balance sheet is translated at consolidation.
- **R11.** Departments have no balances between each other (shared costs are allocated, ME-DEP-6); branches inside one Company net to zero by construction because one entry carries both tags; separate Companies keep due-to and due-from accounts that must agree and are eliminated.
- **R12 and R13.** Translation and elimination happen only at consolidation and never change an entity's own ledger (M2).
- **R15 and R16.** The tax rows are filled from the tax research; until then they state the question, not the answer.
- **R18.** What each shape can report in version one is deliberately small: profit and loss by tag is easy; a balance sheet by department is not.
- **R20.** Per-department and per-branch access would be an RBAC change; RBAC is frozen until the Live switch.

## 5. Data model and contract sketch (a proposal for GL to confirm; Tx does not decide GL's internals)

**Principle:** additive, nullable migrations; a new closed enum value at a boundary is breaking until every consumer decodes unknown values (the Platform Contract Policy), so new `DimensionType` values are declared by consumers first.

| Piece | Sketch | Source in the research or design |
|---|---|---|
| Account currency | `accounts.currency` nullable; v1 only cash and bank assets may be non-null | GL Phase 2a section 5 |
| Foreign memo on lines | `journal_lines.foreign_amount NUMERIC`, `foreign_currency CHAR(3)`, `fx_rate NUMERIC(18,8)`, `fx_rate_id UUID`, all nullable; the base amount stays authoritative and the rate is informational (a memo rate may not reproduce the base amount to the cent) | GL Phase 2a option C; Odoo stores `amount_currency`, `currency_id`, `balance` |
| Rate table | `exchange_rates(id, from, to, rate NUMERIC(18,8), as_of, rate_type SPOT or CLOSING or AVERAGE or HISTORICAL, source, entered_by, entered_at, override_reason)`; never updated in place; scope per PQ-M5 | GL Phase 2a; Dynamics and SAP rate types |
| FX accounts | realised FX gain/loss, unrealised FX gain/loss, rounding, and (only when consolidation is built) a translation reserve; delivered to existing Companies through `POST /companies/{id}/standard-accounts` | survey 4.1; GL review |
| Dimension master | `dimension_values(company_id, type, code, name, active)` and `account_dimension_rules(company_id, account_id, type, rule)` | Odoo plans, Dynamics account structures |
| New dimension types | BRANCH (or reuse LOCATION), COUNTERPARTY (partner Company id). `DimensionType` is a closed enum persisted as text: adding a value is a boundary change, so every service that mirrors it declares the value first (strict decoding). Whether WEB, EA or CBB mirrors of account-postings lines carry `dimensions` is to be checked before adding values. | survey 4.2; GL review |
| Group | `companies.parent_company_id`, ownership percentage, from and to; a group presentation currency | `docs/DDD_Design.md` about line 386 |
| Mapping | `group_account_mapping(group_id, company_id, company_account_code, group_account_code, version)` | Dynamics options, Odoo mapping by code |
| Consolidation run | `consolidation_runs(id, group_id, as_of, presentation_currency, rate_set, mapping_version, status, created_by, created_at)`, `consolidation_lines`, `consolidation_adjustments(kind ELIMINATION or ADJUSTMENT)` | NetSuite elimination subsidiary, Dynamics consolidation entity; hybrid frozen run |

**Reads and writes (paths under GL's `/api`, each new read gets a `fish-contracts` fixture first):** `GET /exchange-rates?from=&to=&asOf=`; operator and accountant writes to the rate table with the change log; `GET /companies/{id}/dimensions/{type}` and its writes; report routes with an optional `dimension` and `value` scope; `POST /groups/{id}/consolidations` and `GET /groups/{id}/consolidations/{run}`; `POST /companies/{id}/revaluations` for the explicit "revalue as at date" action; the intercompany reconciliation report. Shapes are GL's to define.

### 5.1 GL's cells, answers and design commitments (GL session, 2026-10-22)

Written by the GL session against GL's code on master and the Phase 2a design. These are GL's proposals for Femi to decide where a question is open; nothing here is built.

**Matrix A/B cells GL confirms or sharpens (rows owned by GL).**

| Row | GL's cell |
|---|---|
| R2 | Confirmed. The base amount is authoritative; the foreign amount, currency and rate are a memo on the line (option C). The base amount is the foreign amount times the rate, rounded half-even to the base currency's minor units; the rate stored is informational. Gate: PQ-M1 and the ME-FX-3 refusal in place first. |
| R3 | One platform-wide table owned by GL, never updated in place (a correction is a new row), rate type on every row, a Tenant or Company override stored as a separate override row with a reason. Lookup is "latest row on or before the date for that type". Needs PQ-M5. |
| R4 | Realised difference is computed at settlement as the settlement's base amount minus the carrying base amount of the item settled (for a foreign cash or bank book, the book's weighted-average carrying rate, Phase 2a Q3), posted to the realised FX account, tagged with the unit of the item settled (PQ-M6a). |
| R5 | Revaluation is an explicit "revalue as at date" action over accounts with a currency only (monetary accounts); one dated entry per currency, difference to the unrealised FX account; not auto-reversing in version one (GL recommends; Phase 2a Q5 is Femi's); rerun for every later closed period when an earlier one is reopened. The existing `RecordFXRevaluationUseCase` (one receivable, caller-supplied rate and carrying value, no route) is superseded by this action and is retired when it ships. |
| R9 | Confirmed: stock and fixed assets keep the transaction-date rate in the entity's books; they are translated only at consolidation. |
| R10 | Confirmed, with one correction to the survey: GL does write dimension tags today (CUSTOMER, VENDOR, ITEM, VAT_CATEGORY, VAT_DIRECTION, CASH_FLOW_ACTIVITY, PAYROLL_ELEMENT), but never DEPARTMENT, COST_CENTER, PROJECT or LOCATION, and nothing reads any of them except receivables and payables ageing. Values are opaque strings on `JournalLine` until the master list (T-ME-03) exists. |
| R11 | Confirmed. Inside one Company an inter-branch transfer is one entry carrying both branch tags; across Companies each side posts its own entry to a due-to or due-from account per partner (two entries, never one across two ledgers). |
| R12, R13 | GL builds translation and elimination as a reporting layer over frozen inputs and never writes a Company ledger. Do not start before T-ME-04 (licensed text) and Q6. |
| R17 | Period close exists per Company; a consolidation run refuses entities whose reporting dates differ (ME-GRP-7) and uses closed-period trial balances only. |
| R18 | Profit and loss by dimension is one grouped query over journal lines with an explicit Unassigned row and a check that the report total equals the ledger total; the report routes gain an optional `dimension` and `value` scope. A balance sheet by dimension is not version one. |
| R19 | Rates, mapping versions and consolidation runs are written once with who and when; nothing is edited in place. |

**ME-FX-3 (refuse a foreign-currency line), the first thing GL ships.** Today `PostJournalEntryUseCase` and the Record* use cases never compare a line's currency with the Company's; the route accepts any ISO currency per line, and an entry only has to balance within each currency. GL's plan: one shared guard used by the journal post and every Record* use case (sale, obligation, payment, collection, credit note, receipt and issue, payroll, pay-run journal, cash book), refusing with 409 `currency_not_company_currency` and a plain-words detail naming the line and both currencies; additive, no migration; about 1.5 GL days with tests and mutation checks (T-ME-02 raised from 1). **Before it ships**, one read-only check on production (run by Femi or whoever holds database access, never by an agent): `SELECT c.id, jl.currency, count(*) FROM journal_lines jl JOIN journal_entries je ON je.id = jl.journal_entry_id JOIN periods p ON p.id = je.period_id JOIN companies c ON c.id = p.company_id WHERE jl.currency <> c.base_currency GROUP BY c.id, jl.currency;`. Any rows are test data to be reviewed, not silently refused later.

**Data model (section 5): GL confirms it as the starting point, with these commitments.**
- `Company` stays in GL (its table is GL's), so `parent_company_id`, ownership and the group currency are GL migrations; EA owns only the Tenant side and the screens' access. EA is asked before T-ME-17 whether `Tenant.baseCurrency` conflicts with a per-Company currency.
- Every migration is additive and nullable; every new read gets a `fish-contracts` fixture before it ships; a new `DimensionType` value (BRANCH, COUNTERPARTY) is declared by every consumer that decodes dimensions before GL emits it (the account-postings lines CBB reads carry dimension tags, so CBB is checked first).
- New standard accounts (realised and unrealised FX, rounding; later the translation reserve) go into the chart templates and reach existing Companies through `POST /companies/{id}/standard-accounts`, the same path 5510 and 4930 took.
- The rate-table write is an audited accountant or operator act (T-ME-01); it is never reachable by a service account.
- Consolidation runs and their lines are GL tables of their own; eliminations live in a non-posting scope and never in a Company ledger.

**What GL needs from Femi before building past ME-FX-3.** Phase 2a Q1 (which currencies a Company may open), Q2 (rate source and who keeps it current), Q6 (is presentation-currency translation needed), then PQ-M1 (shape of a foreign line, GL recommends C), PQ-M2 (branch is a dimension by default) and PQ-M5 (rate table scope). Q3 to Q5 have GL recommendations in the Phase 2a design and can follow.

**What GL asks of the other owners.** CBB: foreign-currency books, rate field on receipts, payments and transfers, reconciliation in the book's currency (ME-CASH). HR and Payroll: a department or branch per person before any pay-line tag (T-ME-12). WEB: the surfaces in section 11, after GL's fixtures. Tx: the rate sources, the tax rows and the licensed-text check (T-ME-04). EA: the Tenant-side question above.

**Where GL's own design note goes.** Once Femi answers Q1, Q2 and Q6, GL writes the short `docs/GL_Multi_Currency_Departmental_Branch_Consolidation_SPUTO.md` for what this playbook cannot hold: the posting algorithm for realised and unrealised differences, the rounding rule, the report queries and the migration order. Until then this section is GL's position.

## 6. Use cases (U)

Actors: **Business Owner**, **Accountant** (a Tenant's), **Operator** (Prodeo staff), **Femi** (the tax professional), **GL**, **CBB** (GL session for now), **Consumer service** (SOP, POP, IM, HR/Payroll), **WEB**.

**UC-ME-1 Record a foreign-currency receipt or payment (owner GL, CBB).** Pre: the Company has a foreign-currency bank book (UC-ME-4). Main: the Accountant records a USD receipt; WEB shows USD and the Company currency; GL finds the spot rate for the date (UC-ME-8) and stores the foreign amount, the rate and the base amount. Alt: no rate exists for the date: the screen says the rate cannot be set and asks for one (never a default). Err: line in a currency other than the Company's without the foreign fields: refused with a plain 409.

**UC-ME-2 Settle a foreign item and post the realised difference (GL).** Main: a payment settles an item carried at another rate; GL posts the realised difference to the FX account in the Company's currency. Alt: partial settlement: only the settled part is realised. Err: a rate of zero or negative: refused.

**UC-ME-3 Revalue at period end (GL).** Main: the Accountant chooses "revalue as at date"; GL retranslates every monetary item in a foreign currency at the closing rate and posts the difference (reversing or delta, Phase 2a Q5). Alt: a period reopened later: GL requires rerunning every later closed period. Err: no closing rate: refused, nothing posts.

**UC-ME-4 Open a foreign-currency bank account and reconcile it (CBB).** Main: the Accountant opens a USD bank book from the curated list; statement lines reconcile in USD; the base carrying value reconciles via revaluation. Alt: the currency is not on the list: refused with the list shown.

**UC-ME-5 Tag a transaction to a department or branch and report by it (GL, WEB).** Main: a line is tagged Department "Workshop" and Branch "Lagos"; the master list validates both; the P&L is shown with the scope control set to Workshop; Unassigned shows what has no tag; the total equals the ledger. Err: an unknown value is refused. Alt: an account whose rule is REQUIRED refuses an untagged posting.

**UC-ME-6 Allocate a shared cost (GL; optional).** Main: rent is allocated by floor area to departments by a dated allocation journal tagged to each; direct method. Alt: step-down or reciprocal: deferred.

**UC-ME-7 Transfer stock or cash between two branches of one Company (GL).** Main: one entry with two branch tags; it balances inside the Company; a branch report shows each side. Alt: the branches are separate Companies: use UC-ME-11.

**UC-ME-8 Enter an exchange rate (Operator or Accountant, GL).** Main: enter pair, date, rate, type and source; the audit records who and when. Alt: a manual override of an official rate carries a reason. Err: a pair with no source: refused. (Nigeria: the series used is recorded; booking the parallel rate is Femi's decision.)

**UC-ME-9 Set up a foreign branch as a Company (EA, GL, Tx).** Main: the Owner Admin creates a Company in the branch's jurisdiction (its own currency and tax jurisdiction from the registry) and links it to the parent; the branch trades in its own currency. Alt: the branch is domestic: UC-ME-5 instead. Err: the parent is in another Tenant: refused.

**UC-ME-10 Create a subsidiary and link it to a parent (EA, GL).** Main: the Owner Admin creates the subsidiary Company and records the parent and the ownership; the group presentation currency is set (PQ-M4). Err: ownership below control is not version one.

**UC-ME-11 Record an intercompany transaction (GL, HR, SOP, POP).** Main: Company A recharges payroll cost to Company B; A posts a receivable from B and B posts a payable to A, each tagged with the partner; neither entry crosses ledgers. Alt: in transit at period end: both sides show the item and the report flags it. Err: amount or currency mismatch between sides: shown in the reconciliation report (UC-ME-12). Tax: VAT between separate legal entities applies (ME-TAX).

**UC-ME-12 Reconcile intercompany balances (GL).** Main: before consolidation, the report lists each partner pair and the mismatch; the Accountant corrects the sides. Alt: a translation difference is separated from other differences (as SAP's reason codes do).

**UC-ME-13 Run a consolidation (GL, WEB).** Pre: every entity's period is closed to the same date (ME-GOV-2). Main: the Accountant chooses the group, the date and the group currency; GL reads each entity's trial balance, applies the mapping, translates at closing, average and historical rates, eliminates intercompany, and stores the run with its frozen inputs; WEB shows the consolidated report with per-entity columns and drill-back. Alt: re-run: a new run, the old one kept. Err: an entity has no mapping or no rate: refused naming it. Output is labelled management consolidation (ME-GRP-9).

**UC-ME-14 Pay a person taxed under another PAYE jurisdiction (HR/Payroll, Tx).** Main (recommended, PQ-M10): the person is employed by the Company in that jurisdiction; its payroll runs in that currency under that jurisdiction's rules; any cost recharge to the home Company is UC-ME-11. Alt (not recommended for version one): one payroll with per-person jurisdiction and a foreign-currency pay run. Err: today a pay run in a different currency is simply refused (D-1).

**UC-ME-15 Restructure departments (GL).** Main: archive a department and add a new one; past reports are unchanged. Alt: merge or restate: deferred (PQ-M7).

**UC-ME-16 Business Owner views the business (WEB).** Main: a compact "Viewing: All departments / All branches" control scopes a report; Unassigned is explicit; foreign amounts show their currency; totals are base-currency only. Phone first.

**UC-ME-17 Close a period and prepare for consolidation (GL).** Main: each entity's period is closed in order; the consolidation run refuses an open one. Alt: differing period-ends: refused in version one.

## 7. Policy questions for Femi (options and a recommendation; none decided)

Each answer can be one line. **GL's Phase 2a questions (Q1 to Q8 in section 10 of the IAS 21 design) are still unanswered (GL checked the Decisions Log, 2026-10-22; Q1, Q2 and Q6 gate this playbook most) and gate this work; they are carried here by reference, not repeated.** New questions below use the prefix PQ-M.

| # | Question | Options | Recommendation |
|---|---|---|---|
| PQ-M1 | The shape of a foreign line (GL Phase 2a section 4). | (A) the foreign amount is the line's amount with a base equivalent beside it; (B) per-currency clearing pairs; (C) the amount stays in the base currency and the foreign amount and rate are a memo on the line. | (C): additive, keeps every report correct from day one, matches how the standard describes the books. (GL's own recommendation too.) |
| PQ-M2 | What is a branch? | (a) A dimension inside one Company by default, a Company only for a foreign branch with its own currency or tax registration. (b) Always a Company. (c) Always a dimension. | (a). Also: add a BRANCH dimension type, or reuse LOCATION? Recommend a distinct BRANCH. |
| PQ-M3 | Who creates and links a foreign branch or subsidiary Company, and in which Tenant? | (a) The Owner Admin, in the same Tenant as the parent. (b) A separate Tenant per subsidiary. | (a), since a group lives inside one Tenant. |
| PQ-M4 | Purse's structure and the first group. The docs disagree: UK, NI, ROI, SL entities; or Scrip, Purse, Prodeo Capital and a Property SPV; or "one tenant, four companies". Is standalone reporting required for a regulated entity? Is the first output management or statutory consolidation? Which presentation currency? | You state the entities, the parent, the group currency (GBP?), and management versus statutory. | Management consolidation first; presentation currency the parent's. |
| PQ-M5 | Exchange rates: table scope (platform, Tenant, Company); who maintains it; sources (ECB or Bank of England for EUR, GBP, USD; CBN NFEM for NGN; Bank of Sierra Leone indicative rate for SLE); Nigeria official versus parallel; manual override with a reason. | (a) A platform-wide table maintained by an operator, with a Tenant override. (b) Per Tenant. (c) Per Company. | (a): consolidation needs one rate for one date; neither the Bank of England nor the ECB publishes NGN or SLE, so manual entry with source first. For Nigeria, record the official NFEM rate unless you decide otherwise. |
| PQ-M6 | Consolidation mechanism: reporting layer on demand, a persisted consolidation ledger, or a hybrid. | (a) On demand only. (b) Persisted ledger with posted eliminations. (c) Hybrid: computed on demand and persisted as a frozen run with its inputs. | (c): reproducible and auditable without touching any entity's ledger. |
| PQ-M6a | Departments: which dimensions are in version one; mandatory per account or optional; which unit carries the FX line (the item's unit, or unallocated). | Optional by default; REQUIRED only where the owner chooses; FX line follows the settled item. | Optional by default; FX follows the item; profit and loss by department only. |
| PQ-M7 | Translation and treatments: confirm the translation method (closing, average, historical, translation reserve) and the treatment of an intragroup monetary exchange difference against the licensed IAS 21 text; archive-only for renamed or merged departments. | Confirm from the licensed standard before building. | Do not build ME-GRP-5 or -6 until T-ME-04 is done. |
| PQ-M8 | Version-one cut: confirm the first release is foreign cash and bank, departmental and branch reporting, then group link, intercompany and a management consolidation; non-controlling interest, goodwill, equity method, consolidated cash flow and stock profit deferred. | Confirm or move the line. | As stated. |
| PQ-M9 | Hyperinflation (IAS 29): out of scope with a watch status. | Out of scope / in scope for NG. | Out, with Nigeria and Sierra Leone watched. |
| PQ-M10 | PQ-21 resolution: a person taxed under another PAYE jurisdiction. | (a) Employed by a Company (branch or subsidiary) in that jurisdiction; not supported in one payroll. (b) One payroll with a per-person PAYE jurisdiction and a foreign-currency pay run (this relaxes the just-built D-1 refusal on purpose, per person; the per-person jurisdiction would live with Payroll's pay terms, or with HR as a work-location fact: to decide with you). (c) An employer of record outside FiSH. | (a) for version one. |
| PQ-M11 | Foreign customers and suppliers: this phase or a later SPUTO (Phase 2a Q7). | Later / now. | Later. |
| PQ-M12 | Access control by department or branch (an RBAC change). | After Live / now. | After Live. |
| PQ-M13 | The tax rules the research could not settle (section 3.9 and digest section 6) per jurisdiction: the VAT rate for a foreign-currency invoice, the currency of corporation-tax computation, branch registration, PAYE for a person working abroad. | UK and Ireland rows are in digest 6.1 and 6.2; Nigeria and the Mano River rows are added when that report is in. Unresolved: the UK ECB option, the Irish rate date, the currency of branch profits in both, and the rate for translating whole-profit Irish computations (digest 6.3). | Femi confirms the table row by row. |
| PQ-M14 | Does Payroll split pay-run cost by department or branch in the ledger? It needs HR to hold a department or branch per person first. HR's view: yes for branch-based Companies. | (a) Yes, per-line pay-run journal with the tags. (b) Not now. | (a), after Wave 1, because it only needs HR's field and GL's agreed per-line journal. |

## 8. Parked, conflicting or unsourced (never filled in here)

| Item | Why parked |
|---|---|
| IAS 21 and IFRS 10 paragraph numbers | The IFRS site is subscription-gated; confirm against the licensed text (T-ME-04). |
| Intragroup monetary exchange difference on elimination | IFRIC paper keeps it in profit or loss; NetSuite's worked example puts the residual in a CTA account; the researcher's own understanding is unsourced. |
| Purse's structure | Three descriptions in the docs (section 7, PQ-M4). |
| Nigerian rates | Official versus parallel; no authoritative reconciliation of the gap; no confirmed CBN feed or licence terms. |
| Sierra Leone rate | Bank of Sierra Leone publishes PDFs; file names sometimes disagree with the dates inside; no feed. |
| Departmental balance sheet | No source found for its content. |
| Effective-dated dimensions, restating a renamed department | No source found. |
| FRS 102 segment and group treatment, FRS 101, FRS 105 | Not verified. |
| Irish group-specific thresholds; Nigerian CAMA amendments; Sierra Leone small-company thresholds | Not confirmed (digest 3.8). |
| Pending UK legislative changes affecting group exemptions (2026 c. 23, Sch 36) | Effect unknown. |
| Backdated rates, mixed-currency report totals, foreign bank reconciliation design | No source found; the playbook's rules on these are inference. |
| Whether POP checks a PO line currency against the Company's | Not found on master. |

## 9. Tasks (T)

Estimates are rough working days of the owning session, tests first. GL's Phase 2a figures (F1 to F9) are quoted from its design; the rest are Tx's first estimates for the owner to correct. "Femi" means a decision is the blocker.

| ID | Task | Owner | Est. | Depends on |
|---|---|---|---|---|
| T-ME-01 | Platform change log reused for rates, mappings, runs and dimension masters (same as T-TJ-01) | GL | 1.5 (shared) | none |
| T-ME-02 | Refuse a line whose currency is not the Company's unless it carries the foreign fields (ME-FX-3): closes today's silent gap, ships first (GL: 1.5 days; a read-only production check for existing foreign-currency lines comes first, see section 5.1) | GL | 1.5 | none |
| T-ME-03 | Dimension master list, validation and unknown-value refusal; BRANCH and COUNTERPARTY dimension types declared by consumers first | GL | 3 | PQ-M2 |
| T-ME-04 | Confirm IAS 21 and IFRS 10 paragraphs and the intragroup monetary treatment against the licensed text | Tx, Femi | 1 plus access | none |
| T-ME-05 | Femi states Purse's structure, parent, group currency, management versus statutory | Femi | n/a | none |
| T-ME-06 | F1: account currency and the line memo (columns, domain, tests) | GL | 2.5 | PQ-M1, T-ME-02 |
| T-ME-07 | F2: rate table, FX accounts in templates and `AddMissingStandardAccounts` | GL | 2 | PQ-M5, T-ME-01 |
| T-ME-08 | F3: receipts and payments on a foreign book | GL, CBB | 3 | T-ME-06, T-ME-07 |
| T-ME-09 | F7: reconciliation of a foreign statement | CBB (GL) | 2 | T-ME-08 |
| T-ME-10 | Profit and loss by dimension, Unassigned bucket, total-equals-ledger check, optional scope parameter on report routes | GL | 3 | T-ME-03 |
| T-ME-11 | Per-account dimension rule REQUIRED, OPTIONAL or FORBIDDEN | GL | 2 | T-ME-03 |
| T-ME-12 | HR owns a department or branch per person (a field it does not have today); Payroll sends those tags on the per-line pay-run journal; strict DTO declared first | HR, Payroll, GL | 1.5 plus HR's field | T-ME-03; PQ-M14 |
| T-ME-13 | F4: transfers and realised gain or loss | GL | 3 | T-ME-08 |
| T-ME-14 | F5: explicit revaluation action, rounding account | GL | 2.5 | T-ME-13 |
| T-ME-15 | F6: IAS 7 FX effect line in the cash-flow statement | GL | 2 | T-ME-14 |
| T-ME-16 | Branch: BRANCH dimension, inter-branch entries, branch report and branch cash view | GL, CBB | 3 | T-ME-03, T-ME-10 |
| T-ME-17 | Company-as-branch: parent link, group currency (`parent_company_id`, ownership, from and to) and the screens to create it | GL, EA | 3 | PQ-M3, PQ-M4, T-ME-05 |
| T-ME-18 | Intercompany: COUNTERPARTY tag, due-to and due-from accounts per partner, reconciliation report | GL | 4 | T-ME-17 |
| T-ME-19 | Payroll recharge as an explicit intercompany journal (UC-HR12) | HR/Payroll, GL | 2 | T-ME-18 |
| T-ME-20 | Group chart mapping table and its audit | GL | 2 | T-ME-17 |
| T-ME-21 | Translation: rate types average, closing, historical; translation reserve | GL | 3 | T-ME-04, T-ME-07 |
| T-ME-22 | Consolidation run: frozen inputs, eliminations in a non-posting scope, consolidated reports, drill-back, idempotency | GL | 6 | T-ME-18, T-ME-20, T-ME-21, PQ-M6 |
| T-ME-23 | Management-consolidation label and the statutory-use gate | GL, WEB | 0.5 | T-ME-22 |
| T-ME-24 | F8: SOP and POP settle in foreign currency (a later SPUTO) | SOP, POP | later | T-ME-14 |
| T-ME-25 | Tax rows: rate and currency rules per jurisdiction in the rulebook (FX rate for VAT, currency of tax computation) | Tx | 2 plus Femi | tax research; PQ-M13 |
| T-ME-26 | PAYE across jurisdictions: record the version-one rule and the Company-in-that-jurisdiction setup | Tx, HR/Payroll, EA | 1 | PQ-M10 |
| T-ME-27 | `fish-contracts` fixtures for every new read | GL, CM | with each | each read |
| T-ME-28 | WEB: the surfaces in section 11 | FiSH+ER WEB | per WEB | the reads above |
| T-ME-29 | Operator sheet for this area (Omniview) | Tx, CM | 1 | after first release |

## 10. Order (O): foundations before features

1. **Wave 0, foundations (no behaviour change except a refusal):** T-ME-01 change log, T-ME-02 refuse a foreign-currency line that has no memo (closes the silent gap; can ship alone), T-ME-04 licensed-text check, T-ME-05 Femi on Purse. Nothing that moves foreign money starts before T-ME-01 and T-ME-02.
2. **Wave 1, departments (cheap, high value, no FX needed):** T-ME-03, T-ME-10, T-ME-11, T-ME-12. Profit and loss by department, with Unassigned and a total-equals-ledger check.
3. **Wave 2, foreign cash and bank (GL Phase 2a first release F1 + F2 + F3 + F7):** T-ME-06, T-ME-07, T-ME-08, T-ME-09. Gated by Femi's answers to Phase 2a Q1 to Q8 and PQ-M1, PQ-M5.
4. **Wave 3, realised and unrealised FX:** T-ME-13, T-ME-14, T-ME-15.
5. **Wave 4, branches:** T-ME-16, then T-ME-17 for the Company-as-branch exception.
6. **Wave 5, group:** T-ME-18, T-ME-19, T-ME-20 (intercompany and mapping), then T-ME-21 translation and T-ME-22 the consolidation run, T-ME-23 the label.
7. **Later:** T-ME-24 foreign customers and suppliers; deferred items of ME-GRP-8; per-department access after Live.
8. **Tax track in parallel:** T-ME-25 and T-ME-26 follow the tax research and Femi's answers; they feed the rulebook, not the ledger.

**Gates.** Femi's Phase 2a answers and PQ-M1, PQ-M2, PQ-M4, PQ-M5, PQ-M6 gate Waves 2 to 5. RBAC changes wait for the Live switch (ME-GOV-3). Consumer-first for every new field and every new dimension value. Critical path to the first visible gain: Wave 0, then Wave 1 (departments). Critical path to a group view: Waves 2, 4 and 5.

## 11. WEB's half: needs only

For the FiSH+ER WEB session to place and build (it owns how, where and when). Each need is stated as who uses it, on which device, what job; the Business Owner is phone and tablet first; small screen, one primary action, key figure first, no sideways tables at 375, 399 and 411 px; an accountant surface is desktop second and phone read-only.

| # | Surface | User | Device | Job |
|---|---|---|---|---|
| W1 | A currency shown beside every foreign amount; totals in the base currency only | Business Owner, Accountant | phone first | read a foreign amount without a mixed-currency sum |
| W2 | Company jurisdiction and currency shown once in the header (from the shared Company-currency hook) | everyone | phone first | know what currency the Company is in |
| W3 | One compact "Viewing: All departments / All branches" scope control that scopes a report or an entry, with an explicit Unassigned state; details behind a tap | Business Owner | phone first | see a department's or branch's profit and loss |
| W4 | Department and branch pickers on journal lines and where documents carry them (the master list from GL) | Accountant | desktop second | tag a transaction |
| W5 | Exchange-rate view and entry (pair, date, rate, type, source, who entered); the first-use "cannot be set" state when no rate exists | Accountant, Operator | desktop second, phone read-only | maintain rates; understand why an amount cannot be shown |
| W6 | Foreign-currency cash and bank books and their reconciliation (the CBB playbook, not duplicated here): a rate field on receipts, payments and transfers; a base-currency column and running balance per currency in the book table; the "Paid into" picker showing currency; CSV with rate and base columns; a `formatMoney` check for zero-decimal currencies; the attempt-key fingerprint including the rate | Accountant | desktop second | reconcile a USD statement; record and move foreign money |
| W7 | Revaluation run: "revalue as at date", with its result | Accountant | desktop second | close a period |
| W8 | Group view: a Tenant with its Companies, the parent link, the group currency | Owner Admin | phone read, desktop edit | set up and read a group |
| W9 | Consolidated report with per-entity columns, an elimination column, drill-back, and the "management consolidation" label | Accountant, Owner | desktop second, phone read-only | read the group |
| W10 | Intercompany reconciliation report | Accountant | desktop second | clear mismatches before consolidation |
| W11 | Plain-words refusals for every code in this playbook | everyone | phone first | understand what to do |

WEB reported (2026-10-22) that no FX, exchange-rate, revaluation, department, branch, group or consolidation screen exists today, that every Company screen assumes one currency, and that the hard-coded currency literals are being removed in favour of the shared `useCompanyCurrency` hook; this design builds on that hook, not around it. Foreign-currency cash and bank is designed in the CBB playbook (`docs/reports/Playbooks/CBB/WEB_CBB_Playbook_Draft.md`), not duplicated.

## 12. Collaboration status (2026-10-22)

| Party | What was asked | Status |
|---|---|---|
| GL | confirm or correct the ledger side; claim a row; answer which Phase 2a questions are open | GL's cells, answers and commitments are in section 5.1 (2026-10-22); earlier, reviewed (written note, 2026-10-22): corrections folded into section 1, ME-FX-3, ME-RATE-8, section 5; Phase 2a Q1 to Q8 all still unanswered, Q1 (currencies a Company may open), Q2 (rate source) and Q6 (presentation-currency translation) gate this playbook most; GL prefers adding its cells to this document plus one short design note, `docs/GL_Multi_Currency_Departmental_Branch_Consolidation_SPUTO.md`; GL's recommended order: ME-FX-3 guard alone, then Femi's answers to Q1/Q2/Q6 and PQ-M1/M2/M5, then rate table + FX accounts + account currency + memo fields, then realised and unrealised posting, dimension master and P&L by dimension in parallel, then parent link and intercompany, consolidation last |
| CBB (GL session for now) | confirm the cash and bank side | via GL; CM confirms no dedicated CBB backend session exists |
| FiSH+ER WEB (and WEB-CBB through it) | UI needs, existing screens, shell constraints, contact; foreign-currency cash and bank | replied twice; folded into section 11 and ME-CASH-6 to -8 |
| HR/Payroll | department and branch tags on pay lines, UC-HR12, per-person jurisdiction | replied (from the code): no tags today; UC-HR12 designed, not built; no per-person jurisdiction; currency check built locally; folded into ME-SVC-3, ME-DEP-7, ME-IC-4, T-ME-12, PQ-M10, PQ-M14 |
| CM | routing, push, review | informed; digest and claim pushed on request |
| EA | Tenant and Company groups, `Tenant.baseCurrency` versus the Company's | not yet asked; to ask before T-ME-17 |
| SOP, POP, IM | foreign-currency documents (later SPUTO); POP's currency check | not yet asked; later |
| Femi | the policy questions in section 7 and the Phase 2a questions | to be relayed through CM |

## 13. Evidence and what was not verified

**Read:** the digest (`docs/Multi_Entity_Accounting_Research_Digest.md`: three external research reports and one repository survey, with sources), `docs/GL_Foreign_Currency_Accounts_IAS21_Design.md`, `docs/GL_Cash_And_Bank_Books_SRS.md`, `docs/UK/CFO_Accountant_Requirements.md`, `docs/DDD_Design.md`, `docs/FiSH_GL_Engine_Spec.md`, the Tax and Currency Jurisdictions playbook, `docs/Decisions_Log.md`, WEB's reply of 2026-10-22.

**Not verified:**
- Production state: what is deployed, which rows exist.
- IAS 21 and IFRS 10 text and paragraph numbers (digest caveat).
- Every "could not verify" item in the digest sections 1.7, 2.8 and 3.8.
- Whether GL has already drafted its part (the GL session had not replied at the time of writing); GL's cells are Tx's proposal until it does.
- The tax research: UK and Ireland are in digest section 6 (summaries of pages, not statute text; Irish statute pages returned 403); Nigeria and the Mano River countries were still pending at the time of writing, so ME-TAX-2, ME-TAX-3, R15 and R16 are answered for UK and Ireland only.
- HR's statements are from its code read, not run (HR's own caveat).
