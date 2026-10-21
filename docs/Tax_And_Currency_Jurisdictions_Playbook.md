# Tax and Currency Jurisdictions: Playbook (SPUTO)

**Status: DRAFT for Femi, 2026-10-22. Docs only. Nothing here is built, changed or deployed.** Written by the Tax Jurisdiction session at CM's request, relaying Femi (2026-10-22): *"Tax and Currency Jurisdictions can be added as required; this needs management of each country's tax laws over its fiscal years; VAT Categories and their Rates available to IM (and SOP/POP lines) must come from there. Methinks this requires a full playbook."* Also decided the same day (Decisions Log, 2026-10-22): *a Company's Payroll currency must align with its GL currency, and the GL currency with the Tax Jurisdiction the Company operates in; screens use no hard currency defaults.*

**Revision 2 (2026-10-22, later the same day):** folds in GL's and SOP's replies, GL's Company read (built on a branch, not deployed), and a trace of how a Company's jurisdiction is set at onboarding (it is set once and cannot change; new PQ-19, TJ-CO-1a, TJ-CUR-10, TJ-NFR-7, tasks T-TJ-26 to T-TJ-29). Revision 1 merged as PR #449.

**Rule for this document.** Femi is the tax professional and decides policy. Every policy choice is listed in section 9 with options and a recommendation, and none is decided here. No hold or outside-adviser gate is invented. Where a source is secondary, conflicting or missing, the item is parked (section 10), not filled in.

## Contents (the six parts of a Playbook, `docs/Playbook_Definition.md`)

| Part | Where |
|---|---|
| 1. Operator view (what the system does TODAY, what is not built) | section 1 here; the Omniview operator sheet for this area: **not written** |
| 2. Scope (S) | section 2 |
| 3. Plan / SRS (P) | sections 3 to 6 (requirements, data model sketch, contracts, coverage per country) |
| 4. Use cases (U) | section 7 |
| 5. Tasks (T) | section 11 |
| 6. Order (O) | section 12 |
| Consumer needs received | section 8 |
| Policy questions for Femi | section 9 |
| Parked, conflicting, unsourced | section 10 |
| WEB's half (needs only) | section 13 |
| Evidence and what was not verified | section 14 |

## 1. What exists today (verified 2026-10-22)

Read from: GL `origin/master` ff395f2, EA `origin/master` 70c91be, WEB `origin/master` 7fd4889, the `docs/<CODE>/` reference docs (as of 2026-08-22), IM's own statement of its code (master cd1ab20, via IM), and the coordination rows for POP and SOP (no POP backend session is running).

**Correction to the brief.** It said GL's `TaxRule`/`RateStructure` cannot yet express UK small-profits tiering, Ireland's trading/passive split or multi-band VAT. That was true in August and is out of date. `RateStructure` now has four shapes (`Flat`, `Tiered` with marginal relief, `CategorySplit`, `ThresholdExemption`), seeded for the UK (tiered with relief) and Ireland (category split) by migration V31. Multi-band VAT per jurisdiction is the `vat_rates` table (V30). The real gaps are different, and are listed below.

| Area | State today | Where |
|---|---|---|
| Jurisdiction registry | Table `jurisdictions(code, name, enabled, currency)`; all seven enabled (UK, IE, NG, SL, LR, GN, CI). `Jurisdiction` is a two-letter value class, not an enum. Company creation checks the registry; `GET /api/jurisdictions` serves enabled entries to any signed-in caller. **No write route exists** (adding a country is a SQL insert, which today means a migration and a CM deploy). | GL V29, V34, `JurisdictionRoutes.kt` |
| Currency per jurisdiction | UK GBP, IE EUR, NG NGN, SL/LR/GN/CI SLE (V34, "Femi confirmed 2026-10-10"). **No stored onboarded-versus-reference-only status**; that policy lives in the docs and yaml (`onboarded: false` for LRD, GNF, XOF) and the V34 comment. WEB keeps its own copy of the map (`src/lib/jurisdictionCurrency.ts`) and a hard `CURRENCIES` list. | GL V34; WEB |
| Hard currency defaults | `'GBP'` defaults in WEB: `CashBankTab`, `CreateEmployeeTab` (pay-rate currency), `RunPayrollTab`, `BusinessOperationsScreen`, `FinanceScreen`; WEB also derives a default currency from the jurisdiction (`defaultPoCurrency(...)` in `CreateItemTab`, `CreatePurchaseOrderTab`, `DueDateAgingReport`). SOP, POP and IM `src/main` contain no currency string literals (searched; SOP confirms). **But SOP takes the line currency from the caller** (`unitPriceCurrency` and the request currency are hand-typed by the caller; the Company's currency comes from GL's sales posting context); SOP's unreleased S1 refuses ER fee invoices whose currency differs from GL's. POP not verified. HR accepts any currency for a pay rate; I did not find a check that it equals the Company's currency. | WEB; SOP reply; HR `EmployeeRoutes.kt` |
| Company | `Company` has `jurisdiction`, `baseCurrency`, `fiscalYearStartMonth` (stored, "not yet load-bearing"; periods are not derived from it). **Company read (updated 2026-10-22 after GL's reply):** `GET /api/companies/{companyId}` returning `{id, name, baseCurrency (ISO), jurisdiction (the registry code), clientType, fiscalYearStartMonth}` is BUILT on GL branch `gl/company-read` (63dc542, on master ff395f2), fixture `contracts/gl/company.json` on `gl/company-fixture` (7d5b259). GL says it is **not deployed** (CM described it as shipped; check which). Callers: any human with per-Company READ and the `payroll` service account only; **IM, SOP, POP, HR are not on its allow-list.** It carries no jurisdiction display name and no onboarded status (those live on `GET /api/jurisdictions`; GL will add them additively on request). `baseCurrency` also appears inside tax, VAT, cash-book and posting-context responses. GL `/me` and EA `/me` list Companies with access data, not currency or jurisdiction. EA's `Tenant` also stores a `baseCurrency` (a second currency field, see TJ-CO-5). | GL `company.kt`, `MeRoutes.kt`; GL reply; EA `tenant.kt` |
| Setting the jurisdiction (onboarding) | A Company's jurisdiction is set once, at `POST /tenants/{tenantId}/companies`: the body names it, GL accepts it only if it is an enabled registry entry, and sets the currency from the registry (a currency in the request must match; if the registry has none the creator names one). WEB's `AddCompanyForm` uses a registry-fed `JurisdictionSelect`. **There is no route or domain method that changes a Company's jurisdiction afterwards** (searched for PUT/PATCH and for a change method). EA never sees the jurisdiction or the Company currency (its GL gateway only reads reports). | GL `TenantRoutes.kt`; WEB `AddCompanyForm.tsx`; EA |
| Corporation Tax | `tax_rules(jurisdiction, tax_type)` UNIQUE, rate structure as encoded text, **no effective dating**. Seeded for UK, IE, SL only (V31). `POST /companies/{id}/tax` needs a `periodId` and, per rule, `category` (IE TRADING/PASSIVE), `turnover`, `fixedAssets`; a missing input answers 400 `invalid_tax_inputs`, no rule answers 409 `no_tax_rule`. Results persist as `TaxComputation`. NG, LR, GN, CI have no rule. | GL V5, V9, V31, `TaxRoutes.kt` |
| VAT rates | `vat_rates(jurisdiction, category, rate, effective_from, verified)`. IE (5 bands incl. the 1 Jul 2026 move) and UK (3 bands) verified; SL 15% seeded **unverified**; NG, LR, GN, CI none. Only verified rows form a schedule. GL resolves the Company's schedule per request: unverified or absent answers 409 `no_vat_rate_schedule`; a category the schedule lacks answers 400 `vat_category_not_supported`. `GET /companies/{id}/vat-categories?asOf=` lists what a Company may use. | GL V30, `VatCategoriesRoutes.kt`, `RecordSaleAndCollectionRoutes.kt` |
| VAT returns | `VatReturn` over a `VatFilingPeriod` date range (cadence-agnostic), `VAT_DIRECTION` tag (OUTPUT/INPUT). | GL |
| VAT category on products | IM owns it per item: null or one of six names; a sale or purchase line copies it and keeps it frozen; refused when null (`item_has_no_vat_category`). Slice A live; v5 (category by jurisdiction and date) is a draft awaiting Femi. | IM (per IM), `IM_Product_VAT_Category_v5_Extension_Note.md` |
| VAT registration | **No concept anywhere** (searched GL for registration status and VAT number). | GL |
| Payroll tax | Nowhere as data. HR's `PayrollTaxRule` takes bands from the caller; `jurisdiction` is a plain String. PAYE/NI/PRSI/USC/NASSIT/NASSCORP/CNSS/CNPS figures exist only in the docs. | HR; docs |
| Write path and audit | **None for jurisdictions, rates or rules.** No record of who verified or changed a rate (GL's own settlement-discount note calls this a prerequisite before any further country goes live). GL's `audit_log_entries` is per Company, so it is not a home for platform reference data. | GL V27; `GL_Settlement_Discount_VAT_SPUTO.md` |
| Telling the Business Owner of a change | Nothing. | n/a |
| Reference docs | `docs/<CODE>/..._Tax_And_Currency_Settings.md` and `.yaml` for all seven countries (as of 2026-08-22). The yaml headers say nothing reads them, so they are a third hand-synced copy beside the migration seeds. | docs |

**Provenance on file is weak.** Counting the source links in the seven country docs: the UK doc cites no gov.uk or HMRC page (calculator and practitioner sites only); Ireland cites no revenue.ie page; Nigeria, Sierra Leone, Côte d'Ivoire are advisory firms, news and calculators, with a Sierra Leone NRA mail host the only authority link; Liberia has `revenue.lra.gov.lr`; Guinea has `invest.gov.gn`. That does not say the figures are wrong. It says the live `verified = TRUE` rows (UK and Ireland) have no recorded primary source behind the flag.

### Not built (this area)

A write path for jurisdictions, currencies, rates and rules; an audit trail for them; provenance fields; an onboarded-versus-reference-only status; a Company read; effective dating of Corporation Tax rules; Corporation Tax rules for NG, LR, GN, CI; VAT rows for NG, LR, GN, CI; VAT registration status; payroll tax tables; category-by-date lookup (IM v5); a date basis and straddle rule per tax type; telling Business Owners about a change; a rate-correction report; any primary-source provenance. Not deployed or not exercised: I did not check what is live in production (see section 14).

## 2. Scope (S)

**The problem.** FiSH serves Companies in several countries. Each country has its own currency, tax types, rates and fiscal calendar, and they change by law. Today these exist as seeds in migrations and as documents; nothing lets Prodeo add a country, record a law change with its source, schedule it for a date, tell the Business Owner, or prove who changed what. Consumers (IM, SOP, POP, Payroll, WEB) each need a piece of this and today get it from three different places, or hard-code it.

**In scope**

1. The jurisdiction registry and the defined process for adding one as required.
2. Currency per jurisdiction, the onboarded-versus-reference-only policy, and how a screen and Payroll get the Company's currency.
3. Tax types per jurisdiction with effective dating by fiscal year.
4. VAT categories and rates, effective-dated, per jurisdiction and date; how IM, SOP and POP obtain them.
5. The Company's jurisdiction and base-currency READ.
6. Who maintains tax law over time and how a change is rolled out, with an audit trail, and how the Business Owner is told.
7. WEB's needs (listed only; the `FiSH+ER WEB` session writes the front-end section).

**Out of scope here** (each has or needs its own document)

- Filing with a tax authority (ROS, HMRC MTD, e-invoicing): `External_Regulatory_And_Banking_API_Integrations_Requirements_Specification.md`.
- Settlement-discount VAT and similar treatment rules: GL's `GL_Settlement_Discount_VAT_SPUTO.md`. This playbook supplies the storage and governance pattern those rules should use, not their content.
- Partial-exemption apportionment (kept out by Femi, Decisions Log 2026-10-14 D11).
- Payroll computation itself (Payroll's), foreign-currency accounts (`GL_Foreign_Currency_Accounts_IAS21_Design.md`), legal presence and data residency (`FiSH_Localization_Principle.md`).
- Moving rules between services at the Tax extraction: see my earlier scoping note, `Tax_Rules_And_Jurisdictions_Home_Scoping.md` (branch `docs/tax-rules-home-scoping`, tip 9c8151f; check whether merged). Its recommendation stands: rules are service-owned reference data behind a narrow API, not a shared library.

**Principles that bind this work** (each is a decision already taken)

| # | Principle | Source |
|---|---|---|
| P1 | Femi decides policy; CM and sessions never impose holds or outside-adviser gates. | Decisions Log 2026-10-16 |
| P2 | "Tax, VAT, and all the rules that follow it will be governed by the tax jurisdiction of the organisation. These rules will be encoded for each country." | Decisions Log 2026-10-15 |
| P3 | The product or service owns its VAT category (IM); a line freezes it; the rate stays with the tax side, per jurisdiction and period; the VAT figure is calculated by GL. | Decisions Log 2026-10-11, 2026-10-14, 2026-10-15 |
| P4 | Accurate preparation is FiSH's duty; the records a Tenant allows to persist are the Tenant's. FiSH does not audit or vouch. | Decisions Log 2026-10-16 |
| P5 | Fail closed. No verified rule means refuse with a plain message; never default (D4, the `verified` gate). | Decisions Log 2026-10-14; V30 |
| P6 | One owner per kind of data; services integrate through narrow, versioned, consumer-first contracts with fixtures, never by reaching into each other's data. | Decisions Log 2026-10-18; `Cross_Service_Contract_Fixtures_SPUTO.md` |
| P7 | Payroll currency = GL currency = the Tax Jurisdiction's; screens take the Company's GL currency, no hard default; unknown means block or show nothing. | Decisions Log 2026-10-22 |
| P8 | Prodeo is a landlord with no role in Tenant data. The rulebook is platform reference data, not Tenant data. | Decisions Log 2026-10-15 |
| P9 | Strict decoding of auth payloads; the fix for a new field is to declare it, never `ignoreUnknownKeys`. | `CLAUDE.md`, 2026-09-29 |
| P10 | A jurisdiction, a currency or a tax law is added as data, not as code. | Femi 2026-10-05, 2026-10-06 (Option B), 2026-10-22 |

## 3. Plan / SRS (P): requirements

Status column: **Built** exists and meets the requirement; **Partial** exists in part; **No** not built. Priority: M must, S should, C could.

### 3.1 Jurisdiction registry (TJ-REG)

| ID | Requirement | Pri | Today |
|---|---|---|---|
| TJ-REG-1 | The registry holds, per jurisdiction: code (two uppercase letters; UK is the single code for the whole United Kingdom, no GB or NI), name, enabled, and the currency Companies there are created in. | M | Built |
| TJ-REG-2 | The registry also records readiness per tax type (which of: currency onboarded, CIT rule verified, VAT schedule verified, payroll tables), so enabling a country is an informed act. Readiness is shown, not used to block Company creation (tax features fail closed instead, TJ-RUL-6, TJ-VAT-6). | S | No |
| TJ-REG-3 | Adding a jurisdiction follows the defined process in UC-TJ-1, as data, with no code change or deploy. | M | No (process undefined; no write path) |
| TJ-REG-4 | Disabling a jurisdiction stops new onboarding only; existing Companies keep loading. | M | Built |
| TJ-REG-5 | One read serves the list to every consumer (`GET /api/jurisdictions`); no service or screen keeps its own copy. | M | Built (WEB still keeps a map, TJ-CUR-7) |
| TJ-REG-6 | Operators change the registry through an authenticated write path that records who, when, what and why (TJ-GOV-2). | M | No |
| TJ-REG-7 | The registry may carry a display label for the local tax name (VAT, GST, TVA) so screens use the country's word (PQ-14). | C | No |

### 3.2 Currency (TJ-CUR)

| ID | Requirement | Pri | Today |
|---|---|---|---|
| TJ-CUR-1 | A currency reference holds: ISO 4217 code, minor units, symbol, and a status **ONBOARDED** (usable for Companies and postings) or **REFERENCE_ONLY** (documented, not usable). | M | No (policy only in docs) |
| TJ-CUR-2 | Each jurisdiction names one currency (its operating currency for Companies created there). | M | Built |
| TJ-CUR-3 | A new Company's base currency is the jurisdiction's currency. A creator may choose another only when the registry has none, and then only an ONBOARDED currency. | M | Partial (V34 comment; not checked against an onboarded list) |
| TJ-CUR-4 | The onboarded-versus-reference-only status is a recorded, audited decision (Femi's). The 2026-08-22 decision (SLE is the only currency onboarded across the Mano River operation) limits which currencies are ONBOARDED; it does not decide what a screen shows for a Company (Decisions Log 2026-10-22). | M | Partial |
| TJ-CUR-5 | Every money screen takes the Company's GL currency from the Company read. No hard default; if unknown, block the action or show nothing. | M | No (WEB hard defaults) |
| TJ-CUR-6 | Payroll currency equals the Company's GL currency. Payroll refuses a pay rate or pay run in any other currency (409, plain message); the screen shows the currency read-only. | M | No |
| TJ-CUR-7 | WEB's own jurisdiction-to-currency map and `CURRENCIES` list are removed in favour of the registry and the Company read. | M | No |
| TJ-CUR-8 | Zero-decimal currencies (GNF, XOF) are verified end to end (amounts, rounding, storage precision) before any is ONBOARDED. | S | No (not needed while reference-only) |
| TJ-CUR-9 | A Company's base currency is fixed once its first entry posts; a different currency means a different Company (PQ-3). | S | Unknown |
| TJ-CUR-10 | A sales or purchase line, and a request currency, must equal the Company's GL currency; SOP and POP refuse a different one (409, plain message) rather than trusting the caller. Today SOP accepts caller-supplied line currency; its S1 (unreleased) enforces this only for ER fee invoices. WEB derives its defaults from the Company read (TJ-CUR-5), so a mismatch becomes a refusal, not a choice. | M | Partial |

### 3.3 Tax types and the rulebook (TJ-RUL)

The **rulebook** is the effective-dated, per-jurisdiction set of rules for each tax type, held as data.

| ID | Requirement | Pri | Today |
|---|---|---|---|
| TJ-RUL-1 | Every rule row carries: jurisdiction, tax type, the rule, `effective_from`, `verified`, who entered it, who verified it and when, a source reference (authority page or statute), the date it was retrieved, and a note. A row is never overwritten; a change is a new row with a later `effective_from`. | M | Partial (VAT has effective_from and verified; CIT has neither; no provenance fields) |
| TJ-RUL-2 | Each rule family declares its **date basis**: the transaction date (VAT), the period end, or the jurisdiction's own tax year or financial year (CIT, PAYE). Three calendars exist and must not be conflated: the transaction date, the jurisdiction's tax or financial year (UK tax year starts 6 April; Ireland's is the calendar year), and the Company's own fiscal year (`fiscalYearStartMonth`). | M | No |
| TJ-RUL-3 | Where a Company's accounting period straddles a rule change, the rule family has a **straddle policy** per country (apportion by days, rate at period end, or rate at period start). Femi sets it (PQ-8). | M | No |
| TJ-RUL-4 | `RateStructure` shapes stay as they are until a documented rule needs more. Known shapes not yet expressed are listed in section 10 (UK associated-companies divisor, Nigeria's 4% Development Levy, Côte d'Ivoire's non-established-marketplace rate and threshold, Liberia's GST to VAT change). | S | Built (four shapes) |
| TJ-RUL-5 | Corporation Tax rules for NG, LR, GN, CI are added only after Femi settles each country's open item (section 10); each is a data insert once decided. | M | No |
| TJ-RUL-6 | No verified rule means a 409 with a plain message (`no_tax_rule`); never a default from another jurisdiction. | M | Built |
| TJ-RUL-7 | A client can ask what inputs a Company's Corporation Tax rule needs (category, turnover, fixed assets) instead of finding out from a 400. | S | No |
| TJ-RUL-8 | History is kept so a prior period can be recomputed under the rule that applied to it. | M | No (CIT has no history) |
| TJ-RUL-9 | Payroll tax tables (PAYE or equivalent, social contributions) use the same row shape, owned by the service Femi names (PQ-15). | S | No |

### 3.4 VAT categories and rates (TJ-VAT)

| ID | Requirement | Pri | Today |
|---|---|---|---|
| TJ-VAT-1 | The vocabulary is the six names for every jurisdiction (STANDARD, REDUCED, SECOND_REDUCED, SUPER_REDUCED, ZERO_RATED, EXEMPT; EXEMPT also covers out of scope). A seventh value changes GL, POP, SOP, IM and every strict decoder together, in the order EA and WEB first; it needs Femi and a documented rule. | M | Built |
| TJ-VAT-2 | For each jurisdiction the rulebook states which categories are supported and the rate per category by date. | M | Built (`vat_rates`) |
| TJ-VAT-3 | `GET /api/companies/{id}/vat-categories?asOf=` stays the single source for pickers and for IM's validation. | M | Built |
| TJ-VAT-4 | A product's category may differ by jurisdiction and date (IM v5, Decisions Log 2026-10-15). IM resolves (item, jurisdiction, date) to a category; the line freezes it; the rate is resolved by GL at posting. | S | No (draft; PQ-9) |
| TJ-VAT-5 | The rate applied at posting is the one in force on the date basis for VAT. The date basis per jurisdiction (document date or tax point) is a recorded rule (PQ-7). | M | Partial (the request `date` is used) |
| TJ-VAT-6 | Refusals are stable codes with plain messages: GL `no_vat_rate_schedule` (409), GL `vat_category_not_supported` (400), IM `item_has_no_vat_category` (409), IM `vat_category_not_supported_for_jurisdiction` (409, proposed by IM when someone SETS an unsupported category). **GL's `detail` names the category, the date and the jurisdiction** in words a Business Owner can act on (SOP relays GL's detail unchanged: `{error: gl_engine_call_failed, detail, glError}`; SOP asks for this and will map `glError` codes once the final list is fixed). The detail must not tell an owner to "set the rate schedule": owners do not set rates, FiSH does; it should say the rate is not yet available for the country and date. | M | Partial |
| TJ-VAT-7 | A Company has a **VAT registration status**: registered or not, number, from and to dates, and filing cadence. A Company that is not registered does not charge VAT whatever the category (IM item 4). What happens to VAT paid on its purchases is policy (PQ-10). | M | No |
| TJ-VAT-8 | Filing cadence (Ireland bi-monthly, UK quarterly) is data per jurisdiction or registration, not code; `VatFilingPeriod` stays a plain date range. | S | Partial (cadence-agnostic class; no stored cadence) |
| TJ-VAT-9 | Cases the six names cannot express (IM and SOP, 2026-10-22): reverse charge and place of supply (exports, cross-border B2B); a supplier charging differently; a mixed supply split into several rates on one line; a rate that changes inside one service period (a school term straddling a rate change; SOP stamps one category per line and sends one sale date); and recovery treatment beyond the two names EXEMPT and ZERO_RATED. Today: a separate item for sales, POP's correction route for purchases, tuition as EXEMPT per line, trade finance not VAT-bearing at all. A controlled override and a straddle rule are later decisions (PQ-7, PQ-11). | C | Built (workaround) |
| TJ-VAT-10 | Treatment rules beyond the rate (settlement-discount VAT, and others that follow) use this rulebook's row shape and governance, with content owned by their own SPUTOs. | S | No |

### 3.5 Company jurisdiction and currency read (TJ-CO)

| ID | Requirement | Pri | Today |
|---|---|---|---|
| TJ-CO-1 | GL's `GET /api/companies/{companyId}` returns `{id, name, baseCurrency, jurisdiction (code), clientType, fiscalYearStartMonth}`, with the same read authorization as GL's reports. This is the canonical read of a Company's jurisdiction and currency. The jurisdiction's display name and currency status are read from the registry (`GET /api/jurisdictions`), not duplicated here; GL will add them additively if a consumer proves it needs one call. | M | Built on branch (63dc542), not deployed; fixture on `gl/company-fixture` |
| TJ-CO-1a | What is still missing for the Company read: (i) deploy it and merge the fixture; (ii) decide which services may call it: today only humans with READ and the `payroll` service account, so **IM, SOP, POP and HR cannot**; either add them to GL's service allow-list or rely on TJ-CO-4 (the field on the posting contexts they already read); (iii) each consumer declares the fields in its strict mirror before GL's response is relied on; (iv) WEB switches to it (T-TJ-07); (v) the rule on changing a Company's jurisdiction after creation (PQ-19); (vi) EA needs nothing, by design (TJ-CO-3). | M | No |
| TJ-CO-2 | Consumer-first: EA, WEB, IM, SOP, POP, HR declare the new fields in their strict mirrors before GL sends them; a fixture in `fish-contracts` lands first. | M | n/a |
| TJ-CO-3 | EA `/me` does not gain currency or jurisdiction. EA would then hold a tax fact (IM's own view) and EA already stores a second currency field. | S | Recommendation |
| TJ-CO-4 | The posting contexts IM, SOP, POP and Payroll already read (sales, purchase, inventory, payroll) additively carry the Company's `jurisdiction` code, so a service that already makes that call needs no new one. IM asked for this explicitly; SOP confirms nothing in its posting context carries a jurisdiction today. Base currency is already in the sales context (`currency`). This is the recommended route for IM, SOP and POP, which are not on the Company read's allow-list. | S | No |
| TJ-CO-5 | Which currency governs the books is defined: the GL Company's `baseCurrency` governs ledgers, Payroll and screens; EA `Tenant.baseCurrency` is not used for any money display or posting. A check that the two agree at Company creation, or retirement of the EA copy, is for CM and EA. | S | Unknown |

### 3.6 Consumers (TJ-CON)

| ID | Requirement | Pri | Today |
|---|---|---|---|
| TJ-CON-1 | **IM** reads the Company's jurisdiction code and the supported-category list; never a rate. A supported-category list may be cached up to 5 minutes (IM's tolerance); the jurisdiction code is read per call. | M | No (IM has no jurisdiction input today) |
| TJ-CON-2 | **SOP and POP** copy the category from IM onto the line (frozen), send GL the category, and show GL's refusals in plain words. They never hold a rate. Any VAT figure shown on a draft is a GL quote, not a client-side calculation (P3). SOP has no quote step and shows only GL's gross after posting; it also exposes no category list, so WEB takes the list from `vat-categories`. A quote read does not exist; whether one is wanted is for Femi and GL (section 9b). SOP may cache a (company, asOf) category answer for about 5 minutes if it ever adds a preview; for posting it always calls GL. | M | Partial |
| TJ-CON-3 | Every new read has a fixture in `fish-contracts`, and the nightly drift job covers it. | M | n/a |
| TJ-CON-4 | If the tax side is unreachable, posting refuses (503); nothing carries on with a default. | M | Partial |
| TJ-CON-5 | Existing rows are never remapped silently when a jurisdiction drops a category: shown, flagged, refused at the next sale until corrected (IM's rule). | M | n/a |

### 3.7 Governance, maintenance and rollout (TJ-GOV)

| ID | Requirement | Pri | Today |
|---|---|---|---|
| TJ-GOV-1 | Named roles: the **tax professional** (Femi) decides policy and flips `verified`; an **operator** enters drafts. Whether the operator may also verify is PQ-4. | M | No |
| TJ-GOV-2 | An append-only **platform audit** of every rulebook, registry and currency-status change: who, when, old and new value, reason, source reference. It is platform-level (not the per-Company audit log). It is a prerequisite for turning any further country on. | M | No |
| TJ-GOV-3 | A change may be future-dated: entered and verified ahead, live on its date with no deploy; pending changes are visible in a list. | M | No |
| TJ-GOV-4 | Each change follows the rollout checklist in UC-TJ-6: source cited, golden compute tests run, impact listed, owners notified, live on the date. | M | No |
| TJ-GOV-5 | **The Business Owner is told** of a change affecting their Company, before it takes effect and on the day, in plain words that state what FiSH will apply from when. The wording does not advise, and does not take over the owner's responsibility for their records (Decisions Log 2026-10-15, 2026-10-16). Channel and lead time are PQ-12. | M | No |
| TJ-GOV-6 | A document keeps the category and rate it was issued with; reprinting an old document never applies a new rate. | M | Built for lines (frozen category); rate is resolved at posting, so the posted figure stays |
| TJ-GOV-7 | A rate found wrong after postings: FiSH never edits a posted entry. The correction path is UC-TJ-9; policy is PQ-13. | M | No |
| TJ-GOV-8 | Each jurisdiction's rulebook records when it was last reviewed against its authority; an overdue review is shown to Femi. His call whether he wants this (PQ-17). | C | No |

### 3.8 Non-functional (TJ-NFR)

| ID | Requirement |
|---|---|
| TJ-NFR-1 | The posting path takes no extra network hop for a rate: GL resolves the rate from rows it holds, inside the posting call (the atomicity decision of 2026-09-19). |
| TJ-NFR-2 | Reads are small and cacheable by consumers within the limits in TJ-CON-1; the write path is operator-only and never reachable by a Tenant. |
| TJ-NFR-3 | Every computation rule has golden tests with hand-calculated figures; adding or changing a row requires the tests for that row (mutation checks as for other money code). |
| TJ-NFR-4 | A posted VAT line or tax computation can be explained later: it can be traced to the rule row (rate, effective date) that applied. At minimum the rate applied is recoverable from the entry or its return. |
| TJ-NFR-5 | Strict decoding on every new payload (P9); additive, versioned changes only inside a version; closed enums at a boundary count as breaking unless consumers decode unknown values. |
| TJ-NFR-6 | Plain-words messages for every refusal a Business Owner can see; codes stay stable. |
| TJ-NFR-7 | **Guardrails from GL (2026-10-22), binding on any tax-side design.** (a) No posting call takes a rate or percentage from the caller; `record-sale` and `record-obligation` resolve the rate themselves from the rate table at the transaction date, never a cached copy in another service. (b) No second source of truth for rates: whatever the tax side authors lands in GL's `vat_rates` and `tax_rules`, or GL reads it per call; it never lives beside them. (c) A verified row is never changed in place; a rate change is a new `effective_from` row, because editing history changes how past postings recompute. (d) `verified = TRUE` is never set without a primary-source check, since TRUE turns on posting. (e) No posting depends on a synchronous call to another service being up; screens may read from the tax side. GL's (b) and (e) together point at the rule tables staying in, or locally copied into, the posting service (PQ-16). |

## 4. Data model sketch (proposal, not decided)

Evolve the existing tables in place with additive migrations. A new unified rulebook table is not recommended now (minimal build): `vat_rates` and `tax_rules` already hold the two rule families, and a new table would mean moving working, verified data.

| Table | Change |
|---|---|
| `currencies` (new, small) | `code` PK, `minor_units`, `symbol`, `status` (`ONBOARDED` / `REFERENCE_ONLY`), `status_reason`, changed by and at. Seeded: GBP, EUR, NGN, SLE ONBOARDED; LRD, GNF, XOF REFERENCE_ONLY; USD to be decided by Femi (WEB lists it). |
| `jurisdictions` | keep `code, name, enabled, currency`; add optional `tax_name_label` (VAT, GST, TVA), `tax_year_start_month` and `tax_year_start_day` (UK 6 April), `default_vat_cadence`. All optional. |
| `vat_rates` | add `source_ref`, `source_grade` (PRIMARY / SECONDARY), `retrieved_on`, `entered_by`, `entered_at`, `verified_by`, `verified_at`, `note`. Existing seed rows backfilled as `SECONDARY`, "seed V30", pointing at the country doc, until the primary-source pass (T-TJ-03) replaces them. |
| `tax_rules` | add `effective_from` to the key (today UNIQUE on jurisdiction and tax type), plus `verified` and the same provenance fields; add `date_basis` and `straddle_policy` (TJ-RUL-2, -3). Existing rows get `effective_from = 2000-01-01` as the placeholder VAT already uses, `verified = TRUE` for UK and IE only if Femi confirms. |
| `rulebook_change_log` (new, append-only) | `id`, `at`, `actor`, `table_name`, `row_key`, `old_value`, `new_value`, `reason`, `source_ref`. No update or delete; the write path is the only writer. |
| `company_vat_registration` (new, GL Company side) | `company_id`, `registered_from`, `registered_to?`, `registration_number`, `cadence`, `scheme?`. Latest row by date is the status. Owner: GL until the Tax extraction decides otherwise. |

**Fiscal year handling.** Rules key on **dates**, never on a bare "year": `effective_from`, plus the rule family's `date_basis`. A reader derives which rule applies from (transaction date | period end | the period's tax year in the jurisdiction's own calendar) using the registry's tax-year start. The Company's `fiscalYearStartMonth` is used only to cut the Company's own periods; it never selects a rule. This keeps IM v5's choice (effective-dated by date, GL derives the period) consistent with CIT.

## 5. Contracts (reads and writes)

Paths are under GL's `/api`. All reads need a signed-in caller; service accounts follow the existing bypass design. Each new read gets a `fish-contracts` fixture before any consumer sends or expects it.

| # | Route | Purpose | State |
|---|---|---|---|
| R1 | `GET /jurisdictions` | enabled registry entries: code, name, currency; additive: `currencyStatus`, `taxNameLabel` | Exists; additive fields later |
| R2 | `GET /companies/{companyId}` | `{id, name, baseCurrency, jurisdiction (code), clientType, fiscalYearStartMonth}`; callers: humans with READ and the `payroll` service account | Built on GL branch `gl/company-read` (63dc542), not deployed; fixture on `gl/company-fixture` |
| R3 | `GET /companies/{companyId}/vat-categories?asOf=` | `{jurisdiction, asOf, vatScheduleConfigured, categories:[{category, ratePercent}]}`, by Company (there is no by-code read); `ratePercent` is a plain percent string, null for EXEMPT; only verified rows count; none verified answers 200 with `vatScheduleConfigured=false`. SOP asks for `baseCurrency` and a label per category on it so one call serves a picker and a currency; labels are display words (WEB), `baseCurrency` is a candidate additive field | Exists; additive field is a proposal for GL |
| R4 | `GET /companies/{companyId}/tax-rule` | the Company's Corporation Tax rule in words, its required inputs, effective date, whether verified | New (Should, TJ-RUL-7) |
| R5 | `GET /companies/{companyId}/vat-registration` | registration status | New (after PQ-10) |
| W1 | operator routes for jurisdictions, currencies, `vat_rates`, `tax_rules` (create draft, verify, schedule, list pending) | rulebook administration; every call writes `rulebook_change_log` | New. Hosting of the operator screens is for CM and Omniview (section 8); the write API lives with the rulebook owner |
| E1 | owner-notice event or record per affected Company | drives TJ-GOV-5 | New; delivery mechanism with EA |

Failure modes to document in the fixtures: no verified schedule or rule (409 plain), unsupported category (400), Company not found (404), caller without read access (403).

## 6. Coverage per country (what the docs record and what is built)

Figures are from `docs/<CODE>/..._Tax_And_Currency_Settings.md` and `.yaml`, as of 2026-08-22; they are not re-verified here. "Seeded" means a row exists in GL migrations.

| | Currency (registry / own) | Corporation Tax | VAT / GST / TVA | Payroll tables | Open or parked |
|---|---|---|---|---|---|
| **UK** | GBP, onboarded | 19% to 50,000, 25% from 250,000, marginal relief 3/200. **Seeded.** | 20% / 5% / 0%. **Seeded, verified.** | PAYE and NI figures in doc, not modelled; Scotland not represented | associated-companies divisor not modelled; no primary source linked; Windsor Framework VAT-on-goods note for Northern Ireland, moot until relevant |
| **IE** | EUR, onboarded | 12.5% trading, 25% passive. **Seeded.** Knowledge Development Box 6.25% and Pillar Two 15% (above 750m revenue) recorded, not modelled | 23% / 13.5% / 9% (from 1 Jul 2026) / 4.8% / 0%. **Seeded, verified.** | PAYE and USC in doc; **employer PRSI banded, left blank, not sourced** | no primary source linked |
| **NG** | NGN, onboarded (the project's scope for Nigeria is itself flagged in the doc) | 30% flat with small-company exemption on turnover and fixed assets, plus 4% Development Levy. Shape exists (`ThresholdExemption`). **Not seeded.** | 7.5%; zero-rate expanded 1 Jan 2026; exempt list. **Not seeded.** | pension: employer 10% minimum, **under PenCom review** | Development Levy not modelled |
| **SL** | SLE, onboarded | 30% flat (raised from 25%, Finance Act 2026). **Seeded.** | GST 15% single rate. **Seeded, unverified**; "no zero-rating or exemptions" needs confirming | NASSIT 5% / 10% well sourced; **PAYE threshold unit unresolved (old Leone vs new Leone)** | PAYE unit; the one NRA primary PDF would not extract as text |
| **LR** | registry SLE; own LRD **reference only** (USD also circulates) | 25% general, 30% mining and oil. **Not seeded.** | GST 13% (from 12%, effective 1 Jan 2026; telecom 15%); GST to VAT replacement planned 2027, likely 18%, registration from 1 Jul 2026. **Not seeded; unstable.** | **NASSCORP: two incompatible sources, unresolved** | rule shape changes in 2027 |
| **GN** | registry SLE; own GNF **reference only**, zero-decimal | 35% standard, 30% mining. **Not seeded.** | TVA 18% flat. **Not seeded.** | best-sourced income-tax bands (Article 63, Law L/2021/032/AN); employer CNSS 18% | GNF would be the first zero-decimal currency |
| **CI** | registry SLE; own XOF **reference only**, zero-decimal, shared by 8 UEMOA states | resident 25%, non-resident 35%, 30% for non-established online marketplaces over a 50,000,000 threshold. **Not seeded.** | TVA 18%; reduced 9% on listed agricultural inputs from 17 Jan 2026 (exempt, then 18%, then 9% within two weeks). **Not seeded; volatile.** | ITS after the 2024 reform (IS, IGR, CN merged); CNPS itemised | volatility; XOF zero-decimal |

**The one currency tension.** The registry gives LR, GN and CI the currency SLE (Femi, 2026-10-10, following the 2026-08-22 decision), while Femi's 2026-10-22 rule says the GL currency must align with the Tax Jurisdiction. PQ-2 asks Femi whether "the currency the registry declares for that jurisdiction" satisfies that rule, or whether something changes.

## 7. Use cases (U)

Actors: **Operator** (Prodeo staff with the platform operator login), **Tax professional** (Femi), **Business Owner**, **Accountant** (a Tenant's), **Consumer service** (IM, SOP, POP, Payroll, WEB), **GL**.

**UC-TJ-1 Add a jurisdiction (for example ZA).**
Pre: Femi has decided the country is wanted. Main: (1) Operator creates the registry entry disabled, with name and code. (2) Operator names the currency; if it is not in the currency reference, adds it as REFERENCE_ONLY. (3) Operator drafts the rulebook rows the country has sources for (VAT, CIT) as unverified, each with a source reference. (4) Femi reviews each row against its source and verifies. (5) Femi decides whether the currency becomes ONBOARDED (UC-TJ-2). (6) Operator enables the jurisdiction; the audit records every step. Alt: a row Femi will not verify stays unverified and the tax feature for that type answers 409 until it is. Err: a code that is not two uppercase letters is refused.

**UC-TJ-2 Onboard a reference-only currency.**
Main: Femi decides; the operator sets the currency status ONBOARDED with a reason; audit records it; zero-decimal check (TJ-CUR-8) is run first if the currency has no minor unit. Alt: Femi declines; it stays reference only and Companies there keep the registry's declared currency.

**UC-TJ-3 Create a Company in a jurisdiction.**
Main: the registry lists enabled jurisdictions; the creator picks one; GL sets the base currency from the registry; the Company is created. Alt: the registry has no currency for the jurisdiction: the creator names one, and only an ONBOARDED currency is accepted. Err: jurisdiction not enabled, 400/409 plain message. Post: every screen later reads this currency through the Company read.

**UC-TJ-4 A screen needs the Company's currency.**
Main: WEB calls the Company read and uses `baseCurrency`. Err: call fails or currency missing: the screen blocks the action or shows nothing; it does not fall back to GBP or any currency.

**UC-TJ-5 Set a product's VAT category.**
Main: the Owner Admin or an accountant opens the item in IM; IM obtains the Company's jurisdiction and the supported-category list; the picker offers only supported categories; IM saves with a reason (audited). Alt: someone posts an unsupported category directly: IM refuses 409 `vat_category_not_supported_for_jurisdiction` with a plain message ("The UK has no second reduced rate; choose Standard, Reduced, Zero-rated or Exempt"). Err: tax side unreachable: IM refuses the set; it does not save without validation.

**UC-TJ-6 A tax law changes (for example Ireland's 9% second reduced band from 1 July 2026).**
Main: (1) Operator or Femi records the change as a draft row: jurisdiction, tax type, new rate, `effective_from`, source reference and retrieval date. (2) Femi verifies against the source. (3) The rollout checklist runs: golden tests with hand-calculated figures for the new row; list of Companies in the jurisdiction and of documents already dated on or after the effective date; owners' notice scheduled (UC-TJ-8). (4) The row is live on its date with no deploy. (5) Audit has the whole sequence. Alt: the date arrives and the row is unverified: the old rate stays in force and Femi is alerted; nothing guesses. Err: a rate outside 0 to under 1 is refused by the table.

**UC-TJ-7 Sell with VAT.**
Main: the line carries the category frozen from the item; GL resolves the Company's schedule and the rate for the posting date, computes the VAT and posts atomically. Err: no verified schedule: 409 `no_vat_rate_schedule`; category not in the schedule: 400 `vat_category_not_supported`. Both appear to the user in plain words (TJ-NFR-6).

**UC-TJ-8 Tell the Business Owner of a change.**
Main: when a change is scheduled, EA delivers a notice to the owners of Companies in that jurisdiction: what changes, from when, and what FiSH will apply. A reminder and a day-of banner follow (PQ-12). The wording is fixed text approved by Femi and says the owner remains responsible for their records. Alt: the owner has no contact route: shown in-app at next sign-in.

**UC-TJ-9 A rate was wrong and has been posted against.**
Main: Femi corrects the rulebook with a new row and a reason. FiSH does not edit any posted entry. The affected postings are listed for the owner (a report by Company, rate, date range), and the owner decides correcting entries (PQ-13 sets how far FiSH helps). Audit records the correction and the report run.

**UC-TJ-10 Compute Corporation Tax.**
Main: the accountant asks for a computation for a period; GL finds the rule in force on the rule family's date basis; applies the straddle policy if the period crosses a change; computes; persists. Alt: the rule needs an input (IE category; NG turnover and fixed assets): the client read (R4) told it to ask for it. Err: no verified rule: 409.

**UC-TJ-11 Set up payroll currency.**
Main: when a pay rate or pay run is created, Payroll reads the Company's currency and requires equality. Err: a different currency is refused 409 with a plain message; the screen shows the currency read-only.

**UC-TJ-12 Register a Company for VAT (after PQ-10).**
Main: the owner or accountant records the registration (number, effective date, cadence); from that date VAT is charged and reclaimed per the rulebook. Alt: not registered: no VAT lines post; the treatment of VAT paid on purchases follows PQ-10. Err: registration dated after an already-posted VAT entry: refused with a plain message.

**UC-TJ-13 Retire or change a category's support in a jurisdiction.**
Main: a new row ends support from a date. Existing item answers stay but are flagged; the next sale of such an item is refused until corrected; nothing is remapped silently.

**UC-TJ-14 A new Business Owner asks "what VAT will my company use?"**
Main: WEB calls the vat-categories read and shows categories and rates for the Company's jurisdiction and date, in the country's own tax word. Alt: none verified: the screen says VAT is not yet available for this country, with a plain next step.

## 8. Consumer needs received

**IM (c3c92e, code owner, and cbcf0b, author of the Playbook behind it)**, 2026-10-22:
- Holds one answer per product or service: null or one of six names. Stores no rate; never computes VAT.
- Needs the Company's jurisdiction code and the supported-category list (to validate a set and offer choices). Today IM has no jurisdiction input at all. Preferred source: GL's posting context IM already reads per call, with `GET /companies/{c}/vat-categories` as the single source for the list; EA `/me` is second choice but would make EA own a tax fact. Not a deploy setting, because one platform serves several jurisdictions.
- Refusal on SET: 409 `vat_category_not_supported_for_jurisdiction`, naming category and jurisdiction, plain words. At sale and purchase time with no answer for the date: existing 409 `item_has_no_vat_category`.
- Caching: 5 minutes acceptable for the list; none for the jurisdiction code. A `fish-contracts` fixture for any new read; EA, SOP and POP strict mirrors must declare a new field before IM sends one.
- Six names are enough for NG, SL, LR, GN, CI as long as EXEMPT keeps meaning no VAT charged or out of scope; a seventh (OUT_OF_SCOPE) is needed only when GL builds partial-exemption apportionment. Country tax words (GST, TVA) are display, not enum values. Single-rate regimes simply support fewer names.
- A Company that is not VAT-registered should not charge VAT whatever the category; nobody owns registration status yet (this playbook gives it a home: TJ-VAT-7).
- Transaction-dependent VAT cannot be a product category (separate item for sales, POP's correction route for purchases); IM wants to know if Tax wants a controlled override later.
- v5 is a draft nobody has decided; it needs Femi's four answers (back-dating limit, future dates, date versus period, jurisdiction source). IM's message says D10 is undecided; the Decisions Log of 2026-10-15 reads as yes in substance. That mismatch is for Femi to settle (PQ-9).

**POP** (no backend session running; from its coordination rows of 2026-10-14 and 2026-10-18): reads the Item from IM and copies the category frozen on each purchase line; refuses an Item with no category; lines without an item keep an explicit category and can be saved as a reusable service item. Needs no rate and no jurisdiction from the tax side beyond GL's refusals. Its open question is the debit account for a service item, which is not this playbook's.

**SOP** (replied 2026-10-22, from SOP master with S1 ac54dc9 built but unreleased):
- Category: SOP has no jurisdiction or tax config. The category is a required per-line value from the caller (missing = 400 `missing_vat_category`); for a line tied to an IM item, IM's category wins over what the caller typed; an item with no category is refused (409 `item_has_no_vat_category`); nothing defaults to STANDARD. SOP validates only against its own copy of the six-value enum, sends GL the category name and the net amounts, and stores no rate and no VAT amount.
- Jurisdiction: SOP never reads it (no EA call, no setting). Currency: the Company's currency comes from GL's sales posting context; the line `unitPriceCurrency` and request currency are caller-supplied (TJ-CUR-10).
- Missing today: a category list per jurisdiction for a picker, a rate preview or quote, a jurisdiction code in any context, and a read of the rules for the sale date. SOP's suggestion: extend `GET /companies/{c}/vat-categories?asOf=` to return `{jurisdiction, baseCurrency, categories:[{code, label, rate}]}` (R3).
- Cannot express: reverse charge and place of supply, mixed supplies, a rate change inside one service period (school term), recovery beyond the two names (TJ-VAT-9). Tuition is EXEMPT per line today; fee invoices take their category per line from the IM service item; trade finance (Bill for Collection, aval) is not VAT-bearing in SOP.
- GL refusals: SOP relays GL's status and answers `{error: "gl_engine_call_failed", detail: <GL's detail or code>, glError: <GL's code>}`; the message is only as readable as GL's detail. Request: GL's detail names the category and the sale date; SOP will map `glError` once the code list is final (TJ-VAT-6). A 4xx from GL releases the idempotency key; nothing posted.
- Caching: (company, asOf) answers about 5 minutes if a preview is ever added; base currency and jurisdiction effectively static (hours); posting always calls GL. Wants a `fish-contracts` fixture for any new read.

**GL** (replied 2026-10-22):
- Company read: built, not deployed; shape, callers and fixture as in sections 1 and 5; GL adds jurisdiction display name or an onboarded flag additively if asked.
- VAT categories: by Company only; same table the posting routes use, so a screen never sees different rates from a posting.
- Effective dating: `vat_rates` has it; `tax_rules` has none and no plan exists to add it. It needs a decision from Femi (same shape as `vat_rates`: `effective_from` in the key, latest row not after the period end) and is a GL migration plus a `ComputeTaxUseCase` change, not an API-only change (T-TJ-14, PQ-8).
- What the tax side's API must not do: the five guardrails in TJ-NFR-7.

**Payroll (HR/Payroll session)** was not asked; it needs: the Company currency at write time and the rule in TJ-CUR-6. To be put to it before T-TJ-09.

**Open with CM** (section 9b).

## 9. Policy questions for Femi (options and a recommendation; none decided)

Each answer can be one line. A numbered question is only a question.

| # | Question | Options | Recommendation |
|---|---|---|---|
| PQ-1 | Should a jurisdiction be enableable while some of its tax data is missing (today LR, GN, CI are enabled with no VAT or CIT rows)? | (a) Yes; tax features fail closed per tax type (today). (b) Only once currency is ONBOARDED and VAT and CIT are verified. (c) Enable freely but show readiness to the operator and a plain "not yet available" to the Business Owner. | (c). It matches how the system already behaves and tells the owner the truth. |
| PQ-2 | Currency for LR, GN, CI under your 2026-10-22 rule (GL currency aligns with the Tax Jurisdiction). The registry says SLE for all three; their own currencies are LRD, GNF, XOF. | (a) Registry-declared SLE satisfies alignment (status quo; the exception becomes explicit in a currency status). (b) Disable Company creation in LR, GN, CI until their own currency is onboarded. (c) Onboard LRD, GNF, XOF now (two are zero-decimal). | (a) for now, revisited with the first real Tenant there. |
| PQ-3 | Should a Company's base currency be fixed once the first entry posts? | (a) Yes; a different currency is a new Company. (b) Changeable by an accountant with a reason. | (a). |
| PQ-4 | Who enters and who verifies a rule or rate change? | (a) You alone. (b) An operator enters, you verify. (c) Any operator enters and verifies, audited. | (b). |
| PQ-5 | What does "verified" mean? The country docs on file mostly cite advisory firms, calculators and news; few cite the authority. | (a) A primary source (statute or authority page) is required and recorded for every figure that posts. (b) Primary for rates and thresholds, secondary accepted for description. (c) Your judgment, recorded with a note. | (a), starting with the two verified jurisdictions already live (UK, IE) through T-TJ-03. |
| PQ-6 | When a law is enacted ahead of its date (Ireland, 1 July 2026), when do we enter it? | (a) As soon as enacted, verified and future-dated. (b) Nearer the date. | (a); it shows as pending and notifies owners early. |
| PQ-7 | Which date selects a VAT rate: the document date GL uses today, or each country's tax point (invoice, delivery, payment)? And for a supply over a period that straddles a rate change (a school term; SOP stamps one category and one date per line)? | (a) Document date for all (today). (b) A tax-point rule per jurisdiction. (c) For a straddling period, split the line by days into two dated lines. | (a) now, and (b) when the first rate change makes it matter (a sale delivered 30 June and invoiced 2 July is exactly Ireland's case); (c) only if you want straddling terms handled. Your call on whether to wait. |
| PQ-8 | When a company's accounting period crosses a Corporation Tax rate change, how is it handled, per country? | (a) Apportion by days. (b) Rate at period end. (c) Rate at period start. | You tell us per country; the rulebook stores the answer (TJ-RUL-3). No default is assumed. |
| PQ-9 | Can a product's category change from a future date (IM D10), and by date or by period? Four IM answers are needed: back-dating limit, future dates, date versus period, jurisdiction source. | (a) Immediate only (today). (b) Effective-dated by date, GL derives the period (IM v5). | (b), since a law can move a good between bands on a date, with jurisdiction taken from GL's Company read. |
| PQ-10 | VAT registration: is it a Company fact, and what happens when a Company is not registered? | (a) A Company registration record; not registered means no VAT lines post and VAT paid on purchases stays in the cost. (b) Handle with EXEMPT items only. (c) Not now. | (a); registration-threshold monitoring stays out of scope. Your call on the treatment of VAT on purchases. |
| PQ-11 | Transaction-level VAT (exports, reverse charge) beyond a separate item? | (a) Separate item and POP correction (today). (b) A controlled override with a reason, role and audit. | (a) until the first real case. |
| PQ-12 | How is the Business Owner told, and when? | Channels: in-app notice through EA, banner on affected screens, email. Timing: when scheduled, 7 days before, on the day. | In-app notice when scheduled, a reminder 7 days before, a banner on the day; email optional. You approve the wording. |
| PQ-13 | A rate was wrong and has been posted against. | (a) FiSH lists affected postings; the owner decides corrections. (b) FiSH proposes reversing and re-posting entries for the owner's approval. | (a) now; (b) later if it recurs. |
| PQ-14 | Which tax word does a Company see (VAT, GST, TVA)? | (a) The local term from the registry. (b) "VAT" everywhere. | (a). |
| PQ-15 | Who owns payroll tax tables (PAYE or equivalent, social contributions) when Payroll is its own service? | (a) Payroll. (b) The Tax service, read by Payroll. | (a) until the Tax service exists, same row shape so (b) is a move, not a rewrite. |
| PQ-16 | After the Tax extraction, do VAT rates and returns move with it or stay with posting in GL? (The extraction design never placed VAT.) | See `Tax_Rules_And_Jurisdictions_Home_Scoping.md` section 6. GL's guardrails (TJ-NFR-7: no second source of truth, no synchronous dependency at posting) favour the rate tables staying in GL or being locally copied into it. | Decide when the extraction is scheduled; until then the tables stay in GL. |
| PQ-17 | Do you want each jurisdiction's rulebook to carry a "last reviewed" date, with overdue ones shown to you? | (a) Yes. (b) No. | (a), as a reminder to you, not a gate. |
| PQ-18 | Is USD an ONBOARDED currency? WEB lists it; the registry does not. | (a) Yes. (b) No. | Your call; the currency reference needs the answer to seed. |
| PQ-19 | Can a Company's jurisdiction change after it is created? Today it cannot (no route, no method). A Company created in the wrong country, or one that relocates, has no path. | (a) Never; the correct jurisdiction means a new Company. (b) An operator may correct it before the first entry posts, with a reason, audited. (c) Any time with a reason (relocation), which would change the rules applied to history. | (a) with (b) as the correction path; never (c), since it would re-point past postings at a different rulebook. |

### 9b. Questions for CM and peers (architecture, not tax policy)

1. Where do the operator screens for the rulebook live? Recommendation: in Omniview (the operator console, exempt from the WEB convention); the write API lives with the rulebook owner. Needs CM and the Omniview session.
2. GL (answered): the Company read exists on a branch and is not deployed; no VAT quote read exists. Still open: should IM, SOP, POP and HR be added to the Company read's service allow-list, or get the `jurisdiction` code on the posting contexts they already read (TJ-CO-1a, TJ-CO-4)? Recommendation: the posting-context field. And is the VAT quote for drafts wanted at all (Femi, via CM)?
3. EA: which `baseCurrency` governs, EA `Tenant` or GL `Company`, and is a consistency check at Company creation wanted (TJ-CO-5)? EA's Tenant is a group-level record (Purse is one Tenant with Companies in several currencies), so the Tenant field must never drive a money display or posting.
4. Where does the check that the yaml and the seed rows agree run (GL's tests or the nightly drift job)? Better: retire the yaml once the rows carry their sources.
5. Is `GET /api/jurisdictions` registered as a platform contract in `fish-contracts`? (not verified)

## 10. Parked, conflicting or unsourced (never filled in here)

| Item | Why parked |
|---|---|
| Sierra Leone PAYE monthly bands | Sources label the unit old Leone (SLL) or new Leone (SLE) inconsistently; the primary NRA PDF would not extract. Needs a primary source and Femi's reading. |
| Liberia NASSCORP | Two incompatible source versions, recorded as an open conflict. |
| Ireland employer PRSI (Class A) | Banded by earnings; not sourced; left blank. |
| Ireland: settlement-discount VAT | GL's own SPUTO covers it; the credit-note trigger there is unverified for Ireland. |
| UK Corporation Tax associated-companies divisor | The thresholds divide by (1 + associated companies); not modelled. |
| Nigeria Development Levy (4%) | Separate levy beside CIT; no shape or table. |
| Côte d'Ivoire non-established marketplace rate (30%, 50,000,000 threshold) | Novel category; no shape yet. |
| Liberia GST to VAT change (planned 2027) | Rule shape changes; not in effect as of the doc's date. |
| Côte d'Ivoire reduced TVA 9% | Changed three times in two weeks (January 2026); treat as unstable. |
| Nigeria in scope? | The doc itself says Nigeria is otherwise not named in the project; the registry nevertheless enables NG and gives it NGN. Femi's call. |
| Employer pension, Nigeria | Under active PenCom review; treat 10% as current but unstable. |
| Provenance of every figure | See section 1: mostly secondary sources; the live UK and IE `verified` rows have no recorded primary source. T-TJ-03. |
| Rate version on postings | Whether the applied rate should be stored on the VAT line itself (TJ-NFR-4) is a GL design point, not decided. |

## 11. Tasks (T)

Estimates are rough working days of the owning session, tests first. "Femi" means a decision or review is the blocker.

| ID | Task | Owner | Est. | Depends on |
|---|---|---|---|---|
| T-TJ-01 | `rulebook_change_log` (append-only) and a write helper | GL | 1.5 | none |
| T-TJ-02 | Provenance and verification columns on `vat_rates` and `tax_rules` (additive migration; backfill as SECONDARY, "seed") | GL | 1 | T-TJ-01 design |
| T-TJ-03 | Primary-source pass for the rows that are live and verified (UK VAT and CIT, IE VAT and CIT): a source sheet per row, then Femi confirms | Tax session drafts, Femi confirms | 1 plus Femi | none |
| T-TJ-04 | Company read: **built by GL** (branch `gl/company-read` 63dc542, fixture on `gl/company-fixture` 7d5b259). Remaining: CM merges the fixture and releases GL; consumers that will call it (WEB, Payroll, and IM, SOP, POP, HR only if put on the allow-list) declare the fields in their strict mirrors first | GL (release via CM); consumers' mirrors | mirrors only | CM release; allow-list decision (TJ-CO-1a) |
| T-TJ-05 | Add `jurisdiction` code to the sales, purchase, inventory and payroll posting contexts (additive) | GL; IM, SOP, POP, HR declare | 0.5 plus mirrors | T-TJ-04 fixture pattern |
| T-TJ-06 | `currencies` reference table with status; registry returns `currencyStatus` (additive field plus fixture) | GL | 1 | PQ-2, PQ-18 |
| T-TJ-07 | WEB: remove the jurisdiction-currency map, the hard `CURRENCIES` list and every `'GBP'` default; read the registry and the Company read; block when unknown | WEB | per WEB | T-TJ-04, T-TJ-06 |
| T-TJ-08 | WEB tests: UK/GBP, Sierra Leone/SLE, unknown currency, per Femi's 2026-10-22 instruction | WEB | with T-TJ-07 | T-TJ-07 |
| T-TJ-09 | Payroll/HR: pay rate and pay run currency must equal the Company's; 409 plain message; read-only on the screen | HR/Payroll | 1 | T-TJ-04; PQ none |
| T-TJ-10 | Operator write routes for jurisdictions, currency status, `vat_rates`, `tax_rules` (draft, verify, schedule, list pending), each writing the change log; operator-only | GL | 3 | T-TJ-01, T-TJ-02; PQ-4, PQ-5 |
| T-TJ-11 | Operator screens | Omniview | per Omniview | T-TJ-10; 9b item 1 |
| T-TJ-12 | Rulebook change runbook and checklist (UC-TJ-6), notice wording template for Femi's approval | Tax session | 1 | PQ-12 |
| T-TJ-13 | Owner notice: record, EA delivery, WEB banner | EA, WEB | 2 plus WEB | T-TJ-10, PQ-12 |
| T-TJ-14 | `tax_rules` effective dating, `date_basis`, `straddle_policy`, history-preserving lookup; golden tests | GL | 2 | PQ-8; T-TJ-02 |
| T-TJ-15 | `GET /companies/{id}/tax-rule` (required inputs, effective date, verified) | GL | 1 | T-TJ-14 |
| T-TJ-16 | Seed CIT rules for NG, LR, GN, CI, one at a time, each as unverified data | GL data | 0.5 each | Femi's decision per country; section 10 |
| T-TJ-17 | Seed VAT rows for NG, LR, GN, CI (all unverified until Femi verifies) | GL data | 0.5 | section 10 |
| T-TJ-18 | Verify Sierra Leone's VAT rows (flip) after the "no zero-rating or exemptions" confirmation | Femi | n/a | none |
| T-TJ-19 | `company_vat_registration` and posting behaviour for a not-registered Company | GL | 3 | PQ-10 |
| T-TJ-20 | Category by jurisdiction and date (IM v5) | IM | IM's estimate | PQ-9; T-TJ-04, T-TJ-05 |
| T-TJ-21 | Settlement-discount VAT rules on this row shape | GL (own SPUTO) | n/a | T-TJ-02, T-TJ-10 |
| T-TJ-22 | Payroll tax tables on the same row shape | per PQ-15 | n/a | PQ-15; section 10 |
| T-TJ-23 | Tax-point date basis per jurisdiction | GL | n/a | PQ-7 |
| T-TJ-24 | Rate-correction report | GL | n/a | PQ-13 |
| T-TJ-25 | Amend `Tax_Extraction_DDD_Design.md` (stale on the closed enum, unseeded rules, VAT unplaced) | Tax session | 0.5 | PQ-16 |
| T-TJ-26 | GL refusal `detail` names the category, the date and the jurisdiction in owner-readable words (no "set the rate schedule"); then SOP, POP and IM map the final `glError` list | GL, then SOP, POP, IM | 0.5 plus mapping | none; agree the code list |
| T-TJ-27 | SOP and POP refuse a line or request currency different from the Company's GL currency (409, plain); SOP's S1 already does it for ER fee invoices | SOP, POP | 1 each | T-TJ-05 (currency already in contexts) |
| T-TJ-28 | Optional additive `baseCurrency` on `vat-categories` so one call serves a picker and a currency (SOP's request); fixture first | GL | 0.5 | GL's view; fixture |
| T-TJ-29 | Jurisdiction-correction path per PQ-19 (operator, before first posting, audited), if Femi chooses it | GL | 1 | PQ-19; T-TJ-01 |

## 12. Order (O): foundations before features

Safety foundations come first: nothing that can change a rate or a country goes in before the audit trail, and no consumer reads a new field before it is declared.

1. **Wave 0, foundations (no behaviour change):** T-TJ-01 audit log, T-TJ-02 provenance columns, T-TJ-03 primary-source pass for the live rows. A write path (Wave 3) is not allowed to start before T-TJ-01 and T-TJ-02 are merged.
2. **Wave 1, the Company read and the currency fix (unblocks WEB's Pay Terms fix):** T-TJ-04 (and T-TJ-05), then T-TJ-06, T-TJ-07, T-TJ-08, T-TJ-09. Consumer-first: fixtures land first; EA, WEB, IM, SOP, POP and HR mirror the field; only then GL sends it.
3. **Wave 2, decisions:** Femi answers PQ-2 to PQ-5, PQ-8, PQ-10, PQ-12 and PQ-19; these gate Waves 3 and 4. Wave 1 does not wait for them.
4. **Wave 3, the write path and the rollout:** T-TJ-10, T-TJ-11, T-TJ-12, T-TJ-13.
5. **Wave 4, rules:** T-TJ-14, T-TJ-15, then per-country T-TJ-16 and T-TJ-17, T-TJ-18; T-TJ-19; T-TJ-20 when Femi decides PQ-9.
6. **Later:** T-TJ-21 to T-TJ-25.

Critical path to the first visible gain: T-TJ-04 then T-TJ-07 (WEB stops guessing the currency). Critical path to "add a country as required": T-TJ-01, -02, -10 and -11, with Femi's PQ-4 and PQ-5.

## 13. WEB's half: needs only

For the `FiSH+ER WEB` session to turn into screens (it owns how and when):

1. Read the Company through the Company read; use `baseCurrency` everywhere money is shown or entered; no `'GBP'` or any currency default; if unknown, block the action or show nothing.
2. Remove `jurisdictionCurrency.ts`, the hard `CURRENCIES` list and the `defaultPoCurrency(...)` derivation (`CreateItemTab`, `CreatePurchaseOrderTab`, `DueDateAgingReport`); take countries and currencies from the registry and the Company read. The add-Company form already uses a registry-fed jurisdiction picker; its currency choice should follow the registry's currency (and show the explicit "currency set by country" state), not a separate WEB map.
3. Show the currency read-only on payroll screens (pay rate, pay run); never offer a choice.
4. Offer VAT categories only from `vat-categories`, in the country's own tax word, with the rate as a plain percentage for the date; show the plain-words refusals for the codes in TJ-VAT-6.
5. A Company VAT registration screen (after PQ-10).
6. A plain "VAT (or Corporation Tax) is not yet available for your country" state where no verified rule exists, with a next step.
7. A Corporation Tax form that asks only for the inputs the Company's rule needs (after T-TJ-15).
8. A notice for a coming change and a banner on the day (after PQ-12).
9. Tests as Femi asked: UK/GBP, Sierra Leone/SLE, unknown currency.
10. Not WEB's: the operator screens for administering the rulebook belong to Omniview (the exemption of 2026-10-03).

## 14. Evidence and what was not verified

**Read:** GL `origin/master` ff395f2 (`rate_structure.kt`, `tax_type.kt`, `tax_rule.kt` use, `vat_rate_schedule.kt`, `VatCategoriesRoutes.kt`, `ComputeVatCategoriesUseCase.kt`, `TaxRoutes.kt`, `JurisdictionRoutes.kt`, `MeRoutes.kt`, `company.kt`, `ComputePayrollPostingContextUseCase.kt`, migrations V5, V9, V27, V29, V30, V31, V34, route list); EA `origin/master` 70c91be (`/me` DTOs, `tenant.kt`); WEB `origin/master` 7fd4889 (currency literals); HR, SOP, POP, IM `origin/master` (currency literals in `src/main`); `docs/Decisions_Log.md`; `docs/GL_POP_IM_SOP_Coordination.md`; `docs/Playbook_Definition.md`; `docs/Tax_Extraction_DDD_Design.md`; `docs/GL_Settlement_Discount_VAT_SPUTO.md`; `docs/IM_Product_VAT_Category_v5_Extension_Note.md`; `docs/IE/IE_VAT_MVP_Design.md`; the seven `docs/<CODE>/..._Tax_And_Currency_Settings.md` and `.yaml` files; IM's two replies, SOP's reply and GL's reply of 2026-10-22; GL `TenantRoutes.kt` (create Company), WEB `AddCompanyForm.tsx`, EA `src/main` (company and jurisdiction search) for the onboarding trace.

**Not verified:**
- What is live in production: which migrations are applied, which `vat_rates`, `tax_rules` and `jurisdictions` rows exist there, and what `verified` holds in production.
- The statutory content of any figure. Nothing here changes a rate or a rule; the country docs' provenance is weak (section 1).
- Payroll (HR/Payroll session) was not asked; POP has no running backend session.
- Whether the Company read is deployed (GL says no; CM says shipped) and whether `contracts/gl/company.json` is merged: I read GL's and CM's messages, not the branches.
- That EA never sees the jurisdiction: from a search of EA `src/main` for jurisdiction and company-creation code, not a full trace of the onboarding call chain.
- Whether `GET /api/jurisdictions` is registered in `fish-contracts`; whether HR enforces pay-rate currency anywhere I did not search.
- The UK and IE rows in `tax_rules` were seeded by migration; I did not run the computations.
