# Tax and Currency Policy Resolution Playbook

**Status: DRAFT, 2026-10-22. Proposed resolutions only.** Nothing in this playbook is decided until Femi records approval in `docs/Decisions_Log.md`. Where the Decisions Log already answers a question, the answer is cited and is binding as it stands.

**Owner:** Tax Jurisdiction session (Tx). **Evidence file:** `docs/Tax_And_Currency_Policy_Resolution_Research_Digest.md` (sections 1 to 4). **Related playbooks:** `docs/Tax_And_Currency_Jurisdictions_Playbook.md` (TJ-*, UC-TJ-*, PQ-1 to PQ-22, T-TJ-*) and `docs/Multi_Entity_Accounting_Playbook.md` (ME-*, UC-ME-*, PQ-M1 to PQ-M14, T-ME-*). Femi's direction (2026-10-22): the open policy questions in those two playbooks are to be answered by research, with a way to build the answer, not handed back to him.

**Why this playbook exists.** The two playbooks above ended with about forty open policy questions for Femi, many of which he had already answered or which research can answer. This playbook resolves each one with evidence, turns each resolution into a numbered requirement, and gives the build path. It needs nothing further from Femi except his approval: Purse is a Tenant, parked, and will get its own specialised runtime (section 9).

## Contents (the six parts of a Playbook, `docs/Playbook_Definition.md`)

| Part | Where |
|---|---|
| 1. Operator view (what exists today) | section 1 |
| 2. Scope (S): the problem, thoroughly defined | section 2 |
| 3. Plan (P): the solution as numbered requirements (SRS) | section 3 |
| Resolution register: every former question, its answer and its basis | section 4 |
| 4. Use cases (U) | section 5 |
| 5. Tasks (T) | section 6 |
| 6. Order (O) | section 7 |
| What research could not settle (verification tasks, not questions) | section 8 |
| What is still needed from Femi | section 9 |
| Identifier index (traceability) | section 10 |

---

## 1. Operator view: what the system does today

Verified against the two parent playbooks (their section 1) and the Decisions Log, 2026-10-22. This playbook builds nothing; it states what the other playbooks' work must follow.

| Area | Today |
|---|---|
| Jurisdiction registry | GL holds jurisdictions and currencies. Liberia, Guinea and Cote d'Ivoire are enabled with the registry naming SLE as their currency and with no VAT or corporate-tax rows. |
| Company jurisdiction and currency | Set at creation, never changeable (no route, no method). GL's Company read exists on a branch; whether it is deployed is unconfirmed. |
| Rulebook | `tax_rules` and `vat_rates` rows; corporate tax has no effective dating; UK and Ireland VAT rows are verified, Sierra Leone 15% GST is seeded unverified; no write path with an audit trail for operators. |
| VAT date | GL uses the document date, not a tax point. |
| VAT registration | Not modelled. |
| Product VAT category | IM owns it per product; effective-dated per jurisdiction and period (Decisions Log 2026-10-13, 2026-10-15); a sale line freezes a copy. |
| Foreign currency | A Company's ledger is in one currency; each foreign-currency line is not refused today (the gap ME-FX-3 closes). |
| Groups | No parent, no group, no consolidation. |
| Payroll currency | Payroll refuses a pay currency different from the Company's (built, d4f0fe0); no per-person jurisdiction. |

## 2. Scope (S): the problem

### 2.1 The problem

Work on tax, currency and multi-entity accounting has repeatedly stopped on policy questions. The two parent playbooks carry 22 tax-and-currency questions (PQ-1 to PQ-22), 15 multi-entity questions (PQ-M1 to PQ-M14, including PQ-M6a) and GL's eight foreign-currency questions (Phase 2a Q1 to Q8). Four things made this a problem, not just a backlog:

1. **The same questions were asked more than once.** Several are already answered in the Decisions Log (effective-dated VAT categories, VAT recoverable on UK and Irish purchases, no hard-coded currency, RBAC frozen until Live). A question that was answered and then asked again costs the founder time and the builders trust.
2. **Many questions do not need the founder's judgment.** What other accounting systems do, what a tax authority actually says, and what a standard requires are matters of fact. A researcher can establish them. Asking Femi to choose between options he has not been given evidence for pushes research work onto the one person who is the platform's tax professional.
3. **Builders cannot build against an open question.** Each unanswered question blocks named requirements and tasks (for example: no tax point date can be built until PQ-7 is answered; no consolidation until PQ-M4 and PQ-M6).
4. **Some of what was asked rested on wrong or stale numbers.** Three corporate tax rates in the project's own country docs disagree with current sources (Sierra Leone, Guinea, Cote d'Ivoire). Any rule seeded from them would be wrong.

### 2.2 What this playbook resolves

Every question in the three lists above, by one of four routes, recorded for each in section 4:

| Route | Meaning |
|---|---|
| **LOG** | Femi already decided it; the Decisions Log entry is cited and not re-asked. |
| **COMPOSED** | Two or more existing decisions together settle it; the composition is shown. |
| **RESEARCH** | Established by the research in the digest; the evidence section is cited and the answer is a proposal until approved. |
| **TECHNICAL** | An architecture or implementation choice that belongs to the owning service; the owner's recommendation is adopted and cited. |

### 2.3 Out of scope
- Building any of it. The tasks in section 6 are assigned to the owning sessions; this playbook does not push, merge or deploy (only CM does).
- Legal advice. The researchers read statute and authority pages and say where they did not; every conclusion about tax law stays Femi's, as the platform's tax professional, to confirm at approval.
- Hyperinflation accounting (IAS 29), a consolidated cash flow statement, non-controlling interest, goodwill and the equity method (deferred in section 3.6).
- Customer and supplier self-service accounts (parked elsewhere).

### 2.4 Principles that bind this work (already decided)

| # | Principle | Source |
|---|---|---|
| P1 | No currency is hard-coded anywhere; a default comes from the Organisation's tax jurisdiction through the Company read. | Femi D-4, D-5 (Decisions Log 2026-10-22) |
| P2 | A Company's GL currency aligns with the tax jurisdiction it operates in; a Company's payroll currency aligns with its GL currency. | Decisions Log 2026-10-22 |
| P3 | Pay is in the currency of the tax jurisdiction over the person's pay; pay terms are set by the Owner Admin only; HR may prepare a pay run, the Business Owner approves it. | Femi D-2, D-3 |
| P4 | Rates and rules are service-owned, effective-dated reference data read through a narrow versioned API; computation stays with the owning service. | Decisions Log 2026-10-18 |
| P5 | The VAT category of a product depends on jurisdiction and period; it is frozen on the line at order time; no entry covering the date means refused, never defaulted. | Decisions Log 2026-10-13, 2026-10-15 |
| P6 | Currency onboarding is limited to SLE for now; this limits what is onboarded, not what a screen shows for a Company. | Decisions Log 2026-08-22, 2026-10-22 |
| P7 | FiSH prepares and analyses; the Tenant owns its records and is audited. Prodeo is a landlord with no role in Tenant data. | Decisions Log 2026-10-15, 2026-10-16 |
| P8 | Every new piece of work cites the playbook requirement and use case it serves. | Femi, Decisions Log 2026-10-22 (traceability release gate) |

### 2.5 What research can and cannot settle

Research settles facts: what the law and the standards say, what mature systems do, and where sources disagree. It does not settle (a) facts about Femi's own business (which legal entities Purse has), or (b) a choice between two lawful designs where nothing in the evidence prefers one; for (b) this playbook gives a recommendation and its reason, and Femi can overrule it at approval. Every "could not verify" in the digest is carried to section 8 as a verification task, not asked as a question.

---

## 3. Plan (P): requirements

Each requirement states the rule, the question(s) it resolves, its evidence, and the owner. M = must, S = should. "Owner" is the service that builds it; Tx owns the rulebook content.

### 3.1 Jurisdiction and currency lifecycle (PR-LC)

| ID | Requirement | Resolves | Evidence | Owner | Pri |
|---|---|---|---|---|---|
| PR-LC-1 | Each jurisdiction carries an availability status per capability (Company creation, VAT, corporate tax, payroll tax): **Full**, **Partial** (the missing items listed in plain words) or **Planned**. The operator sees the full status; the Business Owner sees a plain "not yet available" for what is missing. | PQ-1 | Digest 1.3 (Odoo, Business Central, SAP publish availability tiers) | GL, WEB | M |
| PR-LC-2 | In a Partial jurisdiction a Company may be created, and only the specific computations that would be wrong are refused (fail closed per tax type, with the stable codes already in TJ-RUL-6 and TJ-VAT-6). Company creation itself is not blocked by missing tax data. | PQ-1 | Digest 1.3 | GL | M |
| PR-LC-3 | A jurisdiction's own legal currency is registry data (GBP, EUR, NGN, SLE, LRD, GNF, XOF). A Company can be created in a jurisdiction only when that currency is ONBOARDED. Liberia, Guinea and Cote d'Ivoire are therefore **Planned for Company creation** until their currency is onboarded by a market-entry decision. This is the composition of the SLE-only onboarding decision (P6) and the alignment rule (P2); the registry's present SLE for those three contradicts both and the evidence (Guinea requires the franc for domestic invoicing). | PQ-2 | Digest 1.2 (Guinea, Cote d'Ivoire, Liberia); Decisions Log 2026-08-22, 2026-10-22 | GL, Tx | M |
| PR-LC-4 | A Company's jurisdiction and base currency may be corrected by an operator, with a reason and an audit record, until the Company's first posting. From the first posting both are locked. After the lock the only path is a new Company with opening balances migrated. There is no in-place edit and no relocation edit. | PQ-3, PQ-19 | Digest 1.1 (NetSuite, Sage Intacct, QuickBooks, SAP, Odoo) | GL, EA | M |
| PR-LC-5 | The number of decimal places and the symbol or prefix of each currency are data in the currency reference, never constants: GBP, EUR, NGN, SLE, LRD and USD have 2 decimals; GNF and XOF have 0. SLE's prefix is "NLe" under the 2024 Bank of Sierra Leone Amendment Act (text to be confirmed, section 8). Amounts are stored as integer minor units with the per-currency exponent. | PQ-18 (support) | Digest 1.2 | GL, WEB | M |
| PR-LC-6 | USD is a **foreign-balance and transaction currency**, not a ledger currency, in every onboarded jurisdiction: it can be held in a cash or bank book once foreign-currency books are built (ME-CASH-*), and invoices in USD follow ME-FX-*. A Company whose books are in USD is a **Liberia-only election** (Liberian businesses may keep books in LRD or USD), per Company, locked at first posting, and built only after the Liberian books rule is confirmed (section 8). | PQ-18 | Digest 1.5, 1.2; Multi-entity digest 6.5 (Liberia s.6(a)) | GL, Tx | M |
| PR-LC-7 | Payroll tax is computed under the jurisdiction of the paying Organisation, and a person's tax jurisdiction defaults to it. There is no per-person jurisdiction, no shadow payroll and no multi-jurisdiction employee. A person who must be taxed in another country is employed by an Organisation in that country (a branch set up as a Company, or a subsidiary); where none exists the case is out of scope and may be referred to an employer of record. | PQ-21, PQ-M10 | Digest 1.4 (the norm for small-business payroll is one legal entity per country) | HR, Payroll | M |

### 3.2 Rulebook governance (PR-GV)

| ID | Requirement | Resolves | Evidence | Owner | Pri |
|---|---|---|---|---|---|
| PR-GV-1 | Two rulebook roles exist: **editor** (enters or proposes a rate or rule) and **verifier** (approves it). The editor of a change cannot be its verifier. Femi holds the verifier role until he delegates it; delegation is his act and is recorded. | PQ-4 | Digest 3.2 (Dynamics Draft-to-Complete; ISO 27001 A.8.32 and SOC 2 CC8.1 evidence expectations; no standard requires segregation, so this is good practice) | GL | M |
| PR-GV-2 | A rule or rate row is immutable once approved. A change is a new effective-dated row. Every change records the requester, the approver, timestamps and a before/after difference, in an append-only change log. | PQ-4, PQ-13 | Digest 3.2, 3.5 | GL | M |
| PR-GV-3 | Every rate or rule row records its source: the instrument (name, number, article), the URL, the source class (**primary** or **secondary**), who verified it and when, and a review-by date. | PQ-5 | Digest 3.3 (ONESOURCE release letters cite the instrument by number and date) | GL, Tx | M |
| PR-GV-4 | A row is **verified** only when (a) a primary source is recorded, or (b) the verifier records a professional judgment with a note, which is shown as such. A row with only secondary sources, or with sources that conflict, is **unverified** or **conflict** and is not used in any computation. | PQ-5 | Digest 3.3; Femi is the tax professional (memory 2026-10-16) | GL | M |
| PR-GV-5 | A row has separate dates: `enactedOn`, `publishedOn`, `effectiveFrom` and `effectiveTo`. A row enacted but not yet effective is **pending** and may be entered as soon as it is enacted and verified, future-dated. A row for a law that is proposed but not enacted is **monitoring** and never feeds a computation. | PQ-6 | Digest 3.4 (ONESOURCE; Sierra Leone's effective date preceded its gazette date) | GL | M |
| PR-GV-6 | Business Owners are told of a pending change: an in-app notice through EA when it is scheduled, a reminder 7 days before, and a banner on affected screens on the day; email is optional. No vendor publishes a fixed lead time, so this schedule is FiSH's own policy. The notice wording is drafted in section 5 (UC-PR-6) for Femi to read at approval. | PQ-12 | Digest 3.4 | EA, WEB | S |
| PR-GV-7 | Each jurisdiction's rulebook carries a **last reviewed** date. Review is quarterly and event-driven (each budget or Finance Act). Overdue jurisdictions are shown to the verifier as a reminder, not a gate. | PQ-17 | Digest 3.3 (PwC "Last reviewed"; TaxAtlas "at least quarterly") | GL, WEB | S |
| PR-GV-8 | A rate that was wrong and has been posted against is never edited. It is superseded by an effective-dated correction row carrying a reason. An **impact query** lists the postings made under the superseded rate in the affected window. The Tenant, not the platform, decides on correcting entries, which are ordinary reversing or adjusting entries; nothing is reversed automatically. Per-jurisdiction correction thresholds (UK 10,000 pounds, 1% of box 6, 50,000 pounds; Ireland 6,000) are configuration data shown with the impact report. | PQ-13 | Digest 3.5, 2.6 | GL, WEB | M |

### 3.3 VAT, GST and TVA behaviour (PR-VT)

| ID | Requirement | Resolves | Evidence | Owner | Pri |
|---|---|---|---|---|---|
| PR-VT-1 | Every VAT posting stores the **invoice date** and a **tax point date**. The rate lookup keys off the tax point date, and the date used and the reason are recorded on the line. In the first release the tax point date defaults to the document date (as GL does today) and any case a jurisdiction's rule would treat differently is not silently mishandled (see PR-VT-2). | PQ-7 | Digest 2.1 | GL, SOP, POP | M |
| PR-VT-2 | The tax point is a per-jurisdiction rule held in the rulebook: UK (basic tax point, early invoice or payment, the 14-day rule); Ireland (registered business customer on invoice basis: the invoice date or the date it was due; unregistered customer: the date of supply; moneys-received basis: supply or advance payment); Guinea (services at collection of price or advance). Nigeria, Sierra Leone, Cote d'Ivoire and Liberia use the document date until a primary text is read (section 8). | PQ-7 | Digest 2.1 | GL, Tx | M |
| PR-VT-3 | One document line has one tax point date and one rate. There is no automatic day-apportionment. A **split-across-change-date** helper produces two lines (or an invoice plus a credit note, as UK Notice 700 section 30 requires) for a supply that straddles a rate change, such as a school term. The user, not the system, chooses between the old and new rate where the authority offers a choice. | PQ-7 | Digest 2.2 (UK and Ireland offer options, not mandates; no ERP apportions automatically) | GL, SOP, WEB | S |
| PR-VT-4 | VAT registration is a **dated fact about the Organisation**: status, VAT number, effective-from date. The registration threshold per jurisdiction is configuration data used for a **monitoring alert** only; registration is a legal act and never switches automatically. | PQ-10 | Digest 2.3 | GL, EA | M |
| PR-VT-5 | For an **unregistered** Organisation: sales carry no VAT and the invoice shows none; VAT charged on purchases is added to the cost of the line, not to an input-VAT account. For a **registered** Organisation, VAT charged on purchases is recoverable (UK and Ireland), as already decided. On registration, new postings change from the effective date; history is not rewritten. | PQ-10 | Digest 2.3; Decisions Log 2026-10-18 | GL, POP, SOP | M |
| PR-VT-6 | Tax treatments are **categories distinct from rates**: standard, each reduced band, zero-rated, exempt, outside scope and reverse charge. Zero-rated and exempt differ because input-VAT recovery differs. The category defaults from the item and the customer. | PQ-11 | Digest 2.4 | GL, IM | M |
| PR-VT-7 | A per-line category override (exports, reverse charge) is allowed only with a **reason, the actor and an audit record**. Until the first real case needs it, the existing route (a separate item and the POP correction) stays. No ERP read offers a general reason-and-approver audit on override, so this is built on first need, not copied. | PQ-11 | Digest 2.4 | GL, IM, WEB | S |
| PR-VT-8 | The tax word (VAT, GST, TVA), the mandatory invoice fields and any required legal wording per tax code are **localisation data per jurisdiction**, not hard-coded labels. Example wording that must be possible: Guinea's franchise statement and Ireland's reverse-charge notation. | PQ-14 | Digest 2.5 | GL, WEB | M |
| PR-VT-9 | A product's VAT category is effective-dated per jurisdiction and period, as already decided. This playbook restates it only so the question is closed in one place. | PQ-9 | Decisions Log 2026-10-13, 2026-10-15 | IM | M |
| PR-VT-10 | VAT on an invoice in a foreign currency is computed in the jurisdiction's currency; the rate type, the rate date and the return currency are per-jurisdiction rulebook data (see `Multi_Entity_Accounting_Playbook.md` ME-TAX-2 and the digest 6.1 to 6.5 there). | (cross-ref) | Multi-entity digest 6 | GL, Tx | M |
| PR-VT-11 | **Rounding of VAT from a VAT-inclusive (gross) amount.** VAT is computed from the gross by the authority's own formula, `vat = round(gross x rate / (100 + rate))`, and `net = gross - vat`, so net plus VAT always equals the typed gross. Rounding is to the currency's minor unit (0 for GNF and XOF, 2 otherwise). A VAT-exclusive amount is `vat = round(net x rate)` per line, never from a document total. One rounding mode is used platform-wide and written down; the authorities read do not prescribe half-even or half-up for exact ties (only that UK retailers must not round down). Asked by CM for GL's shared VAT calculator (GL-T-29), 2026-10-22. | (CM question) | Read 2026-10-22 directly (not yet in the digest): UK Notice 700 paras 7.3.1, 16.6.2, 17.5, 17.6; Revenue pages (no rounding rule found) | GL (commons) | M |

### 3.4 Corporate income tax (PR-CT)

| ID | Requirement | Resolves | Evidence | Owner | Pri |
|---|---|---|---|---|---|
| PR-CT-1 | A corporate tax rate is stored by effective window. When a company's accounting period straddles a rate change, the **UK and Ireland** split the period into notional sub-periods on the change date, time-apportion the taxable profit by days, and pro-rate any thresholds, as their law provides. Every **other** jurisdiction marks the period "straddle - manual determination" instead of assuming a rule. | PQ-8 | Digest 3.6 (UK CTA 2010 s3 and s1172; Ireland TCA 1997 s26(3); Nigeria's authorities conflict; the other four not found) | GL (Tax), Tx | M |
| PR-CT-2 | Seed the corrected rates, each marked with its source class (PR-GV-3): **Sierra Leone 30%** from Finance Act 2026 (secondary-sourced, `unverified` until a primary text is read or the verifier records a judgment); **Guinea** three tiers, 25% general, 35% for telephony, banks, insurance and petroleum importers or distributors, 30% for mining (draft-code source); **Cote d'Ivoire** 25% general and 30% for telecoms, ICT and communication, with **no 35% non-resident rate**; non-resident withholding is a separate rule, not the corporate rate. The project's own country docs and YAML are corrected to match (T-PR-17). | M13 (rate conflicts) | Digest 3.7 | Tx, GL | M |
| PR-CT-3 | Nigeria rule data: a foreign-currency expense is deductible at the CBN official rate for the relevant date or period (NTA s.20(4)); an unrealised exchange difference is not deductible (s.21(g)); the straddling-period rule is flagged unresolved (PR-CT-1). | PQ-M13 | Multi-entity digest 6.4; digest 3.6 | Tx | M |

### 3.5 Exchange rates (PR-RT)

| ID | Requirement | Resolves | Evidence | Owner | Pri |
|---|---|---|---|---|---|
| PR-RT-1 | One platform-wide, GL-owned rate table: currency pair, rate (8 decimals), type (SPOT, CLOSING, AVERAGE, HISTORICAL), source, fetch time, a **carried-forward flag** for weekends and holidays, who entered it, and an override reason where a Tenant or Company overrides. Rows are never updated in place. | PQ-M5, Phase 2a Q2 | Digest 4.5; GL's review | GL | M |
| PR-RT-2 | Sources: the **ECB** reference rates are loaded automatically (the only source with documented bulk formats and a schedule; credit the ECB). **Bank of England** and **CBN** rates are imported semi-manually (the Bank of England excludes some FX data from its open licence; the CBN offers only an Excel export). **Bank of Sierra Leone** rates are entered by hand from its daily PDF. GBP and NGN rates are not redistributed across Tenants until the Bank of England licence exclusion is checked. | PQ-M5 | Digest 4.5 | GL, Tx | M |
| PR-RT-3 | A tax return uses the rate the jurisdiction's rule names, which may differ from the accounting rate: the UK accepts any reliable daily source if consistent with the accounts (CFM61060), Ireland's VAT uses the Central Bank selling rate at the date set in PR-VT-2, Nigeria uses the CBN official rate, Sierra Leone's GST uses the Bank of Sierra Leone mid-rate. The source used is recorded with each tax computation and a per-jurisdiction override sits beside the accounting rate. | PQ-M13 | Digest 4.5; Multi-entity digest 6 | GL, Tx | M |
| PR-RT-4 | Each currency pair carries an **exchangeability flag** and the rate source, so a non-exchangeable currency can be handled later (IFRS for SMEs 30.5A). Hyperinflation accounting stays out of scope; Nigeria and Sierra Leone are watched. | PQ-M9 | Digest 4.3 | GL | S |

### 3.6 Multi-entity and groups (PR-MF)

| ID | Requirement | Resolves | Evidence | Owner | Pri |
|---|---|---|---|---|---|
| PR-MF-1 | The unit of statutory reporting is always the **legal entity**, with a ledger per Company. Consolidation is an **optional layer** defined by a group record with control and ownership percentage. | PQ-M4, PQ-M8 | Digest 4.1 (credit unions are supervised as single legal entities; no consolidated-accounts requirement found) | GL, EA | M |
| PR-MF-2 | A Great Britain credit union entity is modelled with **no controlled subsidiaries**; a credit union service organisation (CUSO) is a **minority investment record**, not a consolidation member. Northern Ireland and Ireland entities may carry a subsidiary flag (Northern Ireland has no legal bar; Ireland's CUSO framework is still a consultation). | PQ-M4 | Digest 4.1 (PRA letter 26 March 2025; PS5/26; Central Bank CP169) | GL | S |
| PR-MF-3 | The first release is **management consolidation** only: a line-by-line combination, a mapped group chart of accounts, elimination journals in an elimination entity, and period-end translation, persisted as a frozen run with its inputs. Non-controlling interest, goodwill, acquisition accounting and uniform-policy adjustments are later, flagged phases. | PQ-M6, PQ-M8 | Digest 4.2 | GL | M |
| PR-MF-4 | Translation follows **IFRS for SMEs Section 30**: balance sheet at the closing rate, income and expense at the average rate, differences in a translation reserve; an intragroup monetary balance is not eliminated silently across currencies (the exchange difference is shown), with a per-balance **net-investment** flag routing it to other comprehensive income; the group presentation currency and each entity's functional currency are fixed at setup. Section 9.18B (translation differences are not recycled on disposal) differs from full IAS 21, which recycles; the choice of basis is flagged for Femi's confirmation at approval, and the full IAS 21 paragraph numbers stay unverified until T-ME-04. | PQ-M7, Phase 2a Q6 | Digest 4.3 (IFRS for SMEs read directly) | GL | M |
| PR-MF-5 | A branch is a **BRANCH dimension inside one Company's ledger** by default. A **separate Company** is used for a separately incorporated subsidiary and for a foreign branch that has its own currency or tax registration. | PQ-M2 | Digest 4.4 | GL, EA | M |
| PR-MF-6 | Department and branch tagging is **optional** at the Company level. A per-account "mandatory" rule exists and is off by default; an overridable default tag per account, partner or user; reports work with untagged lines (an "unassigned" bucket); revaluation postings carry no tags. | PQ-M6a | Digest 4.4 (Business Central, Odoo) | GL | M |
| PR-MF-7 | The group hierarchy and each entity's base currency are validated at setup, because they are hard to change afterwards. | PQ-M4 | Digest 4.2 (NetSuite) | GL, EA | S |
| PR-MF-8 | Defaults adopted from the Multi-entity playbook without new research: a foreign line keeps the base amount authoritative with the foreign amount and rate as a memo (PQ-M1, option C); a foreign branch or subsidiary Company is created by the Owner Admin in the same Tenant (PQ-M3, consistent with the single-Owner-Admin rule); foreign customers and suppliers are a later phase (PQ-M11, Phase 2a Q7); access control by department or branch waits until after Live (PQ-M12, consistent with the RBAC freeze); Payroll splits cost by department or branch once HR holds a department per person (PQ-M14). | PQ-M1, M3, M11, M12, M14 | Multi-entity playbook; Decisions Log (RBAC freeze) | GL, HR | M |

---

## 4. Resolution register

Every former question, with the route (section 2.2), the answer, and the requirement that carries it. "Pending approval" means a proposal until Femi records approval.

### 4.1 Tax and Currency Jurisdictions playbook

| # | Route | Resolution | Requirement | State |
|---|---|---|---|---|
| PQ-1 | RESEARCH | Enable a jurisdiction freely; show readiness to the operator and a plain "not yet available" to the owner; refuse only the wrong computations. | PR-LC-1, -2 | Pending approval |
| PQ-2 | COMPOSED | Liberia, Guinea and Cote d'Ivoire are Planned for Company creation until their own currency is onboarded. | PR-LC-3 | Pending approval |
| PQ-3 | RESEARCH | Base currency locks at the first posting. | PR-LC-4 | Pending approval |
| PQ-4 | RESEARCH | Editor and verifier are different people; Femi verifies until he delegates. | PR-GV-1, -2 | Pending approval |
| PQ-5 | RESEARCH | Primary source or the verifier's recorded judgment makes a row verified; secondary-only or conflicting rows are not used. | PR-GV-3, -4 | Pending approval |
| PQ-6 | RESEARCH | Enter an enacted law as soon as it is verified, future-dated and shown as pending. | PR-GV-5 | Pending approval |
| PQ-7 | RESEARCH | The tax point date selects the rate, per jurisdiction; document date in the first release. | PR-VT-1, -2, -3 | Pending approval |
| PQ-8 | RESEARCH | UK and Ireland time-apportion by days; the other five are flagged manual. | PR-CT-1 | Pending approval |
| PQ-9 | LOG | Effective-dated by jurisdiction and period: yes. | PR-VT-9 | **Decided** (2026-10-13, 2026-10-15) |
| PQ-10 | LOG + RESEARCH | Registration is a dated Organisation fact; unregistered means no VAT charged and purchase VAT in cost; registered means recoverable (UK and Ireland, already decided). | PR-VT-4, -5 | Partly decided (2026-10-18); rest pending approval |
| PQ-11 | RESEARCH | Categories distinct from rates; override with reason and audit on first need. | PR-VT-6, -7 | Pending approval |
| PQ-12 | RESEARCH | In-app notice at scheduling, a reminder 7 days before, a banner on the day. | PR-GV-6 | Pending approval |
| PQ-13 | RESEARCH | Supersede, never edit; impact query; the Tenant decides corrections. | PR-GV-8 | Pending approval |
| PQ-14 | RESEARCH | The local term from the registry (VAT, GST, TVA) as localisation data. | PR-VT-8 | Pending approval |
| PQ-15 | TECHNICAL | Payroll owns payroll tax tables until a Tax service exists; same row shape so a later move is not a rewrite. | (decision of ownership; no new requirement) | Pending approval |
| PQ-16 | TECHNICAL | VAT rate tables stay in GL until the Tax extraction is scheduled; the guardrail TJ-NFR-7 (no second source of truth, no synchronous dependency at posting) prevails; revisit when the extraction is scheduled. | (no change now) | Pending approval |
| PQ-17 | RESEARCH | A last-reviewed date per jurisdiction as a reminder to the verifier, not a gate. | PR-GV-7 | Pending approval |
| PQ-18 | RESEARCH | USD is a foreign-balance and transaction currency; a USD ledger is a Liberia-only election built later. | PR-LC-6 | Pending approval |
| PQ-19 | RESEARCH | An operator corrects jurisdiction before the first posting; afterwards, a new Company. | PR-LC-4 | Pending approval |
| PQ-20 | LOG | Answered (D-2). | P3 | **Decided** |
| PQ-21 | RESEARCH | One Organisation per paying jurisdiction; no per-person jurisdiction. | PR-LC-7 | Pending approval |
| PQ-22 | CM | Settled by CM 2026-10-22: leave the HTTP status as built. | (none) | **Settled** |

### 4.2 Multi-entity playbook

| # | Route | Resolution | Requirement | State |
|---|---|---|---|---|
| PQ-M1 | TECHNICAL | Memo foreign fields on the line, base amount authoritative (GL agrees). | PR-MF-8 | Pending approval |
| PQ-M2 | RESEARCH | A branch is a dimension inside one Company by default; a separate Company when separately incorporated or a foreign branch with its own currency or tax registration; a distinct BRANCH dimension. | PR-MF-5 | Pending approval |
| PQ-M3 | COMPOSED | The Owner Admin creates it, in the same Tenant (single Owner Admin per Tenant). | PR-MF-8 | Pending approval |
| PQ-M4 | LOG + RESEARCH | **Parked by Femi, 2026-10-22: Purse is a Tenant of FiSH, will need a specialised runtime like Education, and the current focus is the Education Runtime.** Purse's entities are therefore not needed now. The platform models a group generically as an optional layer over legal entities; credit unions have no statutory consolidation requirement found and a GB credit union cannot have a subsidiary (kept as evidence for when Purse's runtime is specified). | PR-MF-1, -2 | **Parked** (Femi) |
| PQ-M5 | RESEARCH | One platform-wide table; ECB automated, others semi-manual or manual; carried-forward flag. | PR-RT-1, -2 | Pending approval |
| PQ-M6 | RESEARCH | A frozen run with its inputs (hybrid). | PR-MF-3 | Pending approval |
| PQ-M6a | RESEARCH | Optional; mandatory rule per account, off by default; unassigned bucket. | PR-MF-6 | Pending approval |
| PQ-M7 | RESEARCH | IFRS for SMEs Section 30 as the verified basis; 9.18B difference flagged; full IAS 21 numbers still unverified. | PR-MF-4 | Pending approval (basis choice flagged) |
| PQ-M8 | RESEARCH | Management consolidation first; NCI, goodwill, equity method, consolidated cash flow deferred. | PR-MF-3 | Pending approval |
| PQ-M9 | RESEARCH | Out of scope; watch Nigeria and Sierra Leone; exchangeability flag stored. | PR-RT-4 | Pending approval |
| PQ-M10 | RESEARCH | Same as PQ-21. | PR-LC-7 | Pending approval |
| PQ-M11 | TECHNICAL | Later. | PR-MF-8 | Pending approval |
| PQ-M12 | LOG | After Live; RBAC is frozen. | PR-MF-8 | **Decided** (RBAC freeze, Decisions Log) |
| PQ-M13 | RESEARCH | The tax rules table is filled from the digest; the remaining unverified items are verification tasks (section 8). | PR-CT-2, -3, PR-RT-3 | Pending approval |
| PQ-M14 | TECHNICAL | Yes, after Wave 1, once HR holds a department per person. | PR-MF-8 | Pending approval |

### 4.3 GL's Phase 2a questions (`docs/GL_Foreign_Currency_Accounts_IAS21_Design.md` section 10)

| # | Route | Resolution | Requirement | State |
|---|---|---|---|---|
| Q1 | RESEARCH | Which currencies a Company may open: any currency in the currency reference that an operator has marked **foreign-allowed**, starting with USD, GBP and EUR; each addition is an operator action. This is separate from the ledger-currency onboarding rule (PR-LC-3). | PR-LC-6 | Pending approval |
| Q2 | RESEARCH | A rate table plus override, with the sources in PR-RT-2. | PR-RT-1, -2 | Pending approval |
| Q3 | TECHNICAL | Realised-gain cost flow: GL's recommendation (weighted average) adopted. | (GL design) | GL-owned |
| Q4 | TECHNICAL | Two FX accounts (realised, unrealised): GL's recommendation adopted. | (GL design) | GL-owned |
| Q5 | TECHNICAL | Explicit revaluation now, automatic at period close later: GL's recommendation adopted. | (GL design) | GL-owned |
| Q6 | RESEARCH | Company-currency reporting is enough for a single Company; translation to a presentation currency is done at the group layer with consolidation. | PR-MF-4 | Pending approval |
| Q7 | TECHNICAL | Foreign customers and suppliers later. | PR-MF-8 | GL-owned |
| Q8 | RESEARCH | Build order: section 7. | section 7 | Pending approval |

---

## 5. Use cases (U)

| ID | Use case | Serves |
|---|---|---|
| UC-PR-1 | **An operator corrects a Company created in the wrong country.** Pre: the Company has no posting. Main: the operator opens the Company, changes the jurisdiction (and so the currency) with a reason; GL records the audit entry; the Company read returns the new values. Err: the Company has a posting: GL refuses with a plain message ("Postings exist. Create a new Company in the right country and carry the opening balances across.") and nothing changes. | PR-LC-4 |
| UC-PR-2 | **A Business Owner wants to change the Company's currency after trading.** Main: the screen explains that the currency is fixed once entries exist and offers "create a new Company and migrate opening balances" (the opening-figures route). Err: none. | PR-LC-4 |
| UC-PR-3 | **An owner tries to open a Company in a jurisdiction that is Planned.** Main: the creator lists the jurisdictions; Planned ones are shown as "not yet available" with no creation action; Partial ones allow creation with the missing items listed. | PR-LC-1, -2, -3 |
| UC-PR-4 | **An operator enters a future VAT or corporate rate and the verifier approves it.** Main: the editor enters the row with the instrument, URL and source class; the row is `unverified`; the verifier (Femi) reads it, records primary or a judgment note, and approves; the row becomes `pending` with its effective date. Alt: the editor tries to approve their own change: refused. Alt: only secondary sources exist: the row stays `unverified` and is not used. | PR-GV-1 to -5 |
| UC-PR-5 | **The verifier sees a jurisdiction overdue for review.** Main: the rulebook screen lists jurisdictions past their review-by date; the verifier records a review with a note, which resets the date. No computation is blocked. | PR-GV-7 |
| UC-PR-6 | **A Business Owner is told about a rate change.** Main: when a row becomes pending, EA posts a notice ("From 1 July 2026 the second reduced VAT rate for restaurant and catering is 9%. Your item categories are unchanged; check the items you sell."); a reminder 7 days before; a banner on the day. Wording is drafted here for Femi to read; the owner can dismiss. | PR-GV-6 |
| UC-PR-7 | **A sale is invoiced near a rate change.** Main: the line stores the invoice date and the tax point date, the rate is chosen by the tax point date, and the date used and reason show on the line. Alt: the jurisdiction's rule gives a different tax point than the document date and is not yet modelled: the first release records the document date and the reason "document date (rule not yet modelled)". | PR-VT-1, -2 |
| UC-PR-8 | **A school term billed in advance straddles a rate change.** Main: the accountant uses "split across the change date"; the system produces two dated lines at the old and new rates (or an invoice and a credit note); the user chooses; both are recorded with the reason. | PR-VT-3 |
| UC-PR-9 | **A business registers for VAT mid-year.** Main: the owner records the VAT number and the effective date; postings from that date carry VAT; earlier postings are unchanged. Alt: turnover passes the threshold: the screen shows an alert and does nothing else. | PR-VT-4, -5 |
| UC-PR-10 | **An export sale, and an override with a reason.** Main: the item's category is standard, the customer is outside the country; the accountant overrides the line to zero-rated and enters a reason; the audit record shows who and why. Alt: no reason: refused. | PR-VT-6, -7 |
| UC-PR-11 | **A wrong rate is found after posting.** Main: the verifier supersedes the row with a correction row and a reason; the impact query lists the postings in the window; the Tenant reviews the list and posts its own adjusting entries. Nothing is reversed automatically. | PR-GV-8 |
| UC-PR-12 | **A company's accounting period straddles a corporate rate change.** Main (UK, Ireland): the computation splits the period at the change date, apportions the profit by days and pro-rates thresholds. Alt (other jurisdictions): the computation stops with "straddle - manual determination" and records nothing. | PR-CT-1 |
| UC-PR-13 | **A Sierra Leone accountant loads the day's rate.** Main: the Bank of Sierra Leone publishes a PDF; the accountant enters the mid-rate with the source; GL stores it as SPOT with the entry time. Alt: no rate published for a holiday: the last rate is carried forward and flagged. | PR-RT-1, -2 |
| UC-PR-14 | **Euro rates load automatically.** Main: the ECB reference rates are fetched each working day with the source credited; GL stores each pair; weekends carry the last rate forward with the flag. | PR-RT-1, -2 |
| UC-PR-15 | **A group is set up and a first management consolidation is run.** Main: the owner defines the group (parent, subsidiaries, ownership), the group currency and the mapping; GL runs a consolidation as at a date: translate, combine, eliminate, show the intragroup exchange differences; the run is saved with its inputs. Pre: a Tenant that has a real group to consolidate (none is in focus now; Purse is parked, section 9). | PR-MF-1, -3, -4 |
| UC-PR-16 | **A person needs to be paid under another country's tax.** Main: HR finds the person's work country differs from the Organisation's; the screen explains that payroll is per Organisation and offers: employ them through the Organisation in that country, or record the case as out of scope. | PR-LC-7 |

---

## 6. Tasks (T)

Sizes are working days for the owning session. Tasks extend the parent playbooks' tasks where noted; nothing here is built yet. Only CM pushes, merges and deploys.

| ID | Task | Owner | Days | Depends on |
|---|---|---|---|---|
| T-PR-01 | Availability status per jurisdiction and capability in the registry; operator and owner views; stable codes for refusals. | GL, WEB | 3 | PR-LC-1 decided |
| T-PR-02 | Registry currency correction: Liberia, Guinea, Cote d'Ivoire currency fields set to their own legal currency (LRD, GNF, XOF) as REFERENCE_ONLY, Company creation blocked until ONBOARDED. | GL | 1 | T-PR-01 |
| T-PR-03 | Lock at first posting: reject jurisdiction and currency changes when postings exist; operator correction path before then with reason and audit. | GL, EA | 2 | T-TJ-05 |
| T-PR-04 | Currency reference exponent and prefix as data (GNF and XOF 0; SLE "NLe"); stored minor units; display from the exponent. | GL, WEB | 3 | none |
| T-PR-05 | Rulebook roles (editor, verifier) and the append-only change log; editor cannot verify their own change. Extends T-TJ-01. | GL | 4 | T-TJ-01 |
| T-PR-06 | Source record fields on every rate and rule row (instrument, URL, class, verifiedBy, verifiedOn, reviewBy); `verified` rules (primary or judgment note); unverified rows excluded from computation. | GL | 3 | T-PR-05 |
| T-PR-07 | Separate enacted, published, effectiveFrom and effectiveTo dates; `pending` and `monitoring` states. | GL | 2 | T-PR-06 |
| T-PR-08 | Notices: scheduling notice, 7-day reminder, banner on the day (EA notice route; WEB banner). | EA, WEB | 3 | T-PR-07 |
| T-PR-09 | Last-reviewed date, quarterly review reminder for the verifier. | GL, WEB | 1 | T-PR-06 |
| T-PR-10 | Correction rows and the impact query (postings made under a superseded rate in a window), with per-jurisdiction thresholds as configuration. | GL, WEB | 4 | T-PR-05 |
| T-PR-11 | Tax point date: store invoice date and tax point date on VAT postings; first release defaults to the document date and records the reason. | GL, SOP, POP | 3 | contract fixtures first |
| T-PR-12 | Tax point rules per jurisdiction in the rulebook (UK, Ireland, Guinea modelled; others document date until read). | GL, Tx | 4 | T-PR-11, T-PR-26 |
| T-PR-13 | Split-across-change-date helper (two lines, or invoice plus credit note). | GL, SOP, WEB | 3 | T-PR-11 |
| T-PR-14 | VAT registration as a dated Organisation fact; threshold monitoring alert; unregistered and registered posting behaviour. | GL, EA, POP, SOP | 5 | T-PR-11 |
| T-PR-15 | Tax categories distinct from rates (zero-rated, exempt, outside scope, reverse charge); per-line override with reason, actor and audit, on first need. | GL, IM, WEB | 4 | T-PR-14 |
| T-PR-16 | Localisation data: tax word, mandatory invoice fields, per-tax-code legal wording per jurisdiction. | GL, WEB | 3 | none |
| T-PR-17 | Correct the corporate rate data and docs: Sierra Leone 30%, Guinea three tiers, Cote d'Ivoire 25%/30% with no 35% non-resident rate; non-resident withholding as separate rules; update the country docs and YAML. | Tx | 2 | none |
| T-PR-18 | Corporate rate by effective window; UK and Ireland straddling-period apportionment by days with pro-rated thresholds; other jurisdictions flagged "manual determination". | GL (Tax) | 5 | T-PR-07 |
| T-PR-19 | Nigeria rule data (CBN official rate deduction, unrealised difference not deductible). | Tx, GL | 2 | T-PR-06 |
| T-PR-20 | Rate table (types, source, fetch time, carried-forward flag, override rows); never updated in place. | GL | 4 | none |
| T-PR-21 | ECB automatic load; manual entry screen for BSL, CBN and Bank of England imports; GBP and NGN redistribution held until the licence is checked. | GL, WEB | 4 | T-PR-20 |
| T-PR-22 | Per-jurisdiction tax-return rate rule and source recorded with each computation. | GL, Tx | 3 | T-PR-20, T-PR-06 |
| T-PR-23 | Exchangeability flag per currency pair. | GL | 1 | T-PR-20 |
| T-PR-24 | Group record, ownership, control; GB credit union rule (no controlled subsidiaries; CUSO as investment record); hierarchy and base-currency validation at setup. **Parked** with consolidation: no Tenant in focus has a group; revisit when a Tenant's runtime needs one. | GL, EA | 5 | a Tenant with a real group (Purse is parked) |
| T-PR-25 | Management consolidation: mapping, elimination entity, translation per IFRS for SMEs Section 30, net-investment flag, frozen run. Extends the Multi-entity tasks. **Parked** with T-PR-24. | GL | 12 | T-PR-20, T-PR-24, T-ME-04 |
| T-PR-26 | Verification reading of the primary texts listed in section 8, recording each result in the rulebook. | Tx | 6 | none |
| T-PR-27 | Payroll: confirm the one-Organisation-per-jurisdiction rule on the screens; the refusal message for a person in another country (UC-PR-16). Extends T-TJ-09. | HR, Payroll, WEB | 2 | none |
| T-PR-28 | Fixtures in `fish-contracts` for every new read, consumer first. | GL and each consumer | per task | each read |
| T-PR-29 | Operator sheet for the Omniview Tax area: how to enter, verify, supersede and review a rule. | Tx, EA | 2 | T-PR-05, T-PR-10 |

## 7. Order (O): foundations before features

- **Wave 0, now, no code dependency:** T-PR-17 (correct the rate data), T-PR-26 (verification reading), the ME-FX-3 production check (T-ME-02's pre-check). These protect everything after them.
- **Wave 1, foundations:** T-PR-04 (currency exponent and prefix), T-PR-05 to T-PR-07 (governance write path), T-PR-01 to T-PR-03 (availability and lock), T-PR-20 (rate table). These must land before any feature that relies on them.
- **Wave 2, VAT behaviour:** T-PR-11 to T-PR-16 (tax point, split helper, registration, categories, localisation).
- **Wave 3, rates and returns:** T-PR-21 to T-PR-23, T-PR-18, T-PR-19, T-PR-22.
- **Wave 4, notices and corrections:** T-PR-08 to T-PR-10, T-PR-27, T-PR-29.
- **Wave 5, groups (parked):** T-PR-24, T-PR-25. Not scheduled: Purse is parked and the focus is the Education Runtime. Revisit when a Tenant's runtime needs a group, after the rate table and the IAS 21 text task (T-ME-04) are done.
- **Always:** T-PR-28 (fixtures) with each read.

Dependencies that cross sessions: GL (most tasks), IM (T-PR-15), SOP and POP (T-PR-11, -13, -14), EA (T-PR-03, -08, -14, -24), HR and Payroll (T-PR-27), WEB (every screen; routed through FiSH+ER WEB). Claim a row in `docs/GL_POP_IM_SOP_Coordination.md` before starting any of them.

## 8. What research could not settle (verification tasks, not questions)

Each is task T-PR-26 unless noted. None is asked of Femi; each ends as a recorded rule or a note in the rulebook.

| # | Item | Why unresolved | Digest |
|---|---|---|---|
| V-1 | Nigeria VAT: time of supply (earlier of invoice or payment, versus cash basis), the small-company threshold, and NTAA s.39 (assess and pay in the currency of the transaction) against any naira-conversion rule. | Secondary sources conflict; the Act's operative text was read only in part. | 2.1, 2.3; multi-entity digest 6.4 |
| V-2 | Sierra Leone GST Act (time of supply s.19, invoice s.62, registration threshold) and the Bank of Sierra Leone (Amendment) Act 2024 wording on the currency and pricing exception. | The parliament site and the NRA site failed on certificate errors. | 1.2, 2.1, 2.3 |
| V-3 | Liberia: Revenue Code ss.6, 212 and 214 to 216 primary text; GST and the 2027 VAT regime and rate (15% versus 18%); buying versus selling rate. | Primary text not read by the researcher who covered the books rule; sources conflict. | 1.2, 2.2; multi-entity digest 6.5 |
| V-4 | Guinea: confirm the draft code (PROJET, applicable 1 January 2022) matches the enacted law; BCRG regulation; employer social charges and pay currency. | The enacted text is a scanned image. | 2, 3.7 |
| V-5 | Cote d'Ivoire: the CGI text for VAT time of supply, export treatment (exempt versus 0%) and registration thresholds; the withholding rate on service fees to non-residents (20% versus 25%). | CGI body text not read; sources conflict. | 2.1, 2.4, 3.7 |
| V-6 | Sierra Leone corporate tax 30%: a primary text. | Secondary sources agree; no primary read. | 3.7 |
| V-7 | Nigeria: the definition of "official" exchange rate, and the transition rule for periods straddling 1 January 2026. | Authorities conflict (Minister's guidelines versus NRS February 2026 guidance). | 3.6, 4.5 |
| V-8 | UK and Ireland: the UK ECB rate option for VAT; the Irish VAT rate date; the currency of branch profits; the Irish whole-profit translation rate; Irish correction threshold 6,000. | Sources differ or were not reachable (Irish statute pages returned 403). | multi-entity digest 6.3; 2.6 |
| V-9 | Full IAS 21 and IFRS 10 paragraph numbers. | Licensed text not read; IFRS for SMEs read directly instead (T-ME-04). | 4.3 |
| V-10 | The Bank of England licence terms for GBP rates (the LSEG exclusion), and the Bank of Sierra Leone and CBN terms of use. | Not stated on the pages read. | 4.5 |
| V-11 | Liberian books-currency election (PR-LC-6): confirm the rule before building. | No primary text on the currency of books of account found beyond s.6(a). | 1.2, 1.5 |
| V-13 | VAT rounding: Ireland's and Nigeria's rule for rounding VAT on an invoice or from a gross amount, and the tie-breaking mode in each of the three jurisdictions. | Revenue pages searched found no rounding rule; Nigeria not researched; HMRC states only which direction rounding may go. | (this playbook, PR-VT-11) |
| V-12 | The Irish CUSO framework (Central Bank CP169) and whether credit unions in any of the three jurisdictions must produce group accounts. | A consultation, not final; no requirement found. | 4.1 |

## 9. What is still needed from Femi

**No fact is needed now.** The one open fact, Purse's legal entities and parent, is not needed: Femi decided on 2026-10-22 that Purse is a Tenant of FiSH, is **parked**, and will require a specialised runtime just like Education. The current focus is the Education Runtime. The group and consolidation work (PR-MF-1 to PR-MF-4, UC-PR-15, T-PR-24, T-PR-25) therefore stays in the plan as generic capability but is not scheduled; PQ-M4 is parked, not answered. When Purse's runtime is specified, its structure is the first input (the documents describe it three ways: UK, Northern Ireland, Republic of Ireland and Sierra Leone entities; Scrip, Purse, Prodeo Capital and a Property SPV; or one Tenant with four Companies).

**Femi's approval.** Approval is recorded in `docs/Decisions_Log.md`. Until then every requirement here is traced to a DRAFT playbook. Three choices are flagged in the text for his eye at approval, because nothing in the evidence prefers one lawful design: the verifier role being his until delegated (PR-GV-1), the IFRS for SMEs basis for management consolidation versus full IAS 21 (PR-MF-4, only relevant once a group exists), and the 7-day reminder schedule (PR-GV-6).

## 10. Identifier index (for traceability)

IDs are stable: never renumbered or reused; a dropped item keeps its ID and is marked withdrawn; new items are appended. Status: DRAFT until Femi records approval in the Decisions Log.

| Kind | IDs | Where defined |
|---|---|---|
| Requirements, lifecycle | PR-LC-1 to PR-LC-7 | 3.1 |
| Requirements, governance | PR-GV-1 to PR-GV-8 | 3.2 |
| Requirements, VAT | PR-VT-1 to PR-VT-11 | 3.3 |
| Requirements, corporate tax | PR-CT-1 to PR-CT-3 | 3.4 |
| Requirements, exchange rates | PR-RT-1 to PR-RT-4 | 3.5 |
| Requirements, multi-entity | PR-MF-1 to PR-MF-8 | 3.6 |
| Principles | P1 to P8 | 2.4 |
| Resolution register | rows for PQ-1 to PQ-22, PQ-M1 to PQ-M14 (including PQ-M6a), Phase 2a Q1 to Q8 | 4 |
| Use cases | UC-PR-1 to UC-PR-16 | 5 |
| Tasks | T-PR-01 to T-PR-29 | 6 |
| Verification items | V-1 to V-13 | 8 |
