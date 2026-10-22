# Tax Service (fish-tax) Extraction Playbook

**Status: DRAFT, 2026-10-22. Docs and design only; no code, no contract fixtures and no GL change until CM confirms.** Nothing here is approved until Femi records approval in `docs/Decisions_Log.md`.

**Owner:** Tax Jurisdiction session (Tx). **Related:** `docs/Tax_Extraction_DDD_Design.md` (2026-09-19, the original design; its section 8 questions are answered here), `docs/Tax_And_Currency_Policy_Resolution_Playbook.md` (section 11 and PR-TX-1 to PR-TX-4), `docs/Tax_And_Currency_Jurisdictions_Playbook.md`, `docs/Tax_And_Currency_Policy_Resolution_Research_Digest.md`.

**Decisions this playbook rests on (all Femi, 2026-10-22; items 1 to 4 logged):**
1. "All things Tax should be abstracted to Tx."
2. Extract now: "No time like the present. Let us extract things that need to do with taxes to Tx. It will provide context for PAYE, and VAT." This overrules the earlier "after the Live switch and UAT" timing. It runs in parallel with, and does not delay, the 24 October VAT deliveries in GL.
3. "He should provide a window into that portal." Tx provides a Tax screen in the shared front end.
5. **"Go ahead with Tx. Provide Tax context for each country's jurisdiction, e.g. UK VAT, PAYE, Self Employed etc."** (relayed by CM). The go is beyond docs: code in `fish-tax` once the infrastructure is ready, and fixtures in `fish-contracts` on a branch; the GL `RateSource` port (T-TS-03) still waits for GL's 24 October work. Scope added: a catalogue of all tax types per jurisdiction (TS-11).
6. Femi adds (relayed by CM): Tx "will provide the tax context for each country's jurisdiction ... within each fiscal year". The catalogue and the contract are therefore organised by **tax year** per jurisdiction as well as by date (TS-13).
8. Femi answered the maintenance question (logged): who watches each tax authority for changes is **"The business owner"**. Section 3.11 reconciles this with Tx's duty to keep its rows accurate, and records the confirmation mechanism (TS-15).
7. Femi adds (relayed by CM): Tx "will maintain [the tax context] for all jurisdictions we work in: UK, IE etc." Maintenance is a **standing responsibility** of Tx, for every jurisdiction in the registry, present and added later as reference data (TS-14, section 3.10).
4. The repo and service name is **`fish-tax`** (Femi "Yes" to CM's suggestion): Kotlin, Ktor and Exposed like its siblings, its own database, service accounts like the others. This answers question 3 of the original design.

## Contents (the six parts of a Playbook, `docs/Playbook_Definition.md`)

| Part | Where |
|---|---|
| 1. Operator view: what exists in GL today | section 1 |
| 2. Scope (S) | section 2 |
| 3. Plan (P): decisions and numbered requirements (SRS) | section 3 |
| 4. Use cases (U) | section 4 |
| 5. Tasks (T) | section 5 |
| 6. Order (O) | section 6 |
| The WINDOW: Tax screen requirements for WEB | section 7 |
| PAYE: what Tax provides to Payroll | section 8 |
| Evidence and what was not verified | section 9 |
| Identifier index | section 10 |

---

## 1. Operator view: what the Tax context is in GL today

Read from the GL checkout (`26a7df6` and the `fish-contracts` pin), 2026-10-22.

| Kind | What | Where |
|---|---|---|
| Tables | `jurisdictions` (code, name, enabled, currency), `tax_rules` (jurisdiction, tax type, rate structure as encoded text; UNIQUE per jurisdiction and type), `tax_computations` (company, period, rule, taxable profit, tax due), `vat_rates` (jurisdiction, category, rate, effective-from, verified; primary key jurisdiction + category + effective-from), `vat_returns` (company, filing period, VAT control account, output, input, net due, direction) | migrations V5, V9, V25, V29, V30, V31, V34; `infrastructure/persistence/tax_tables.kt`, `vat_rate_tables.kt`, `jurisdiction_tables.kt` |
| Routes | `GET /jurisdictions`; `POST` and `GET /companies/{companyId}/tax` (corporate tax); `GET /companies/{companyId}/vat-categories` (the Company's jurisdiction, rates as of a date); `POST /companies/{companyId}/vat-return` | `JurisdictionRoutes.kt`, `TaxRoutes.kt`, `VatCategoriesRoutes.kt`, `VatReturnRoutes.kt` |
| Domain and use cases | `domain/tax`: `tax_rule`, `tax_type`, `rate_structure`, `tax_computation`, `vat_category`, `vat_rate_schedule`, `vat_filing_period`, `vat_return`, `repositories`, `ids`; `ComputeTaxUseCase`, `ComputeVatCategoriesUseCase`, `ComputeVatReturnUseCase` | `domain/tax`, `application` |
| Who reads VAT rates at posting | `RecordSaleUseCase`, `RecordSupplierObligationUseCase`, `RecordSupplierCreditNoteUseCase` (through the VAT rate repository) | `application` |
| Contract fixtures (`fish-contracts`) | `gl/jurisdictions.json`, `gl/vat-categories.json`, `gl/vat-categories-not-configured.json`, `gl/vat-return.json`, `gl/tax-computation.json`, `gl/tax-computation-no-tax-rule.json`, `gl/company.json` | `contracts/contracts/gl` |
| Access vocabulary | `ManagedModule.TAX` (EA and GL tenancy) | stays in EA and GL |
| Payroll tax | Payroll has its own `PayrollTaxRule` with `TaxBand`s (progressive PAYE shape), deliberately **not** populated with real figures | `PAYROLL/.../domain/payroll_tax_rule.kt` |
| Not there | A rate change log or history for `vat_rates` (a rate change is a SQL insert); a write path with roles; tax point date; registration; availability status | (see the Policy Resolution playbook) |

Two facts shape the design. First, `domain.tax` has no incoming dependencies from other GL contexts apart from the three posting use cases above, which read VAT rates. Second, the registry in the fixture still shows SLE as the currency of Cote d'Ivoire, Guinea and Liberia and lists Ghana with no currency; PR-LC-3 of the Policy Resolution playbook corrects this once the rulebook is Tax's.

## 2. Scope (S): the problem

### 2.1 The problem
Tax rules are scattered. GL holds the rates and the corporate and VAT computations; Payroll holds an empty PAYE shape; SOP, POP, CBB, IM and WEB each need a rate or a jurisdiction setting and today get it from GL's routes or from literals in screens. Four problems follow:
1. **No single owner.** A rate change is an insert in GL's database with no record of who made it, from what source, or who verified it.
2. **Consumers depend on GL's shape.** A document owner that needs a VAT rate calls a GL route that is Company-scoped and entangled with posting, and Payroll cannot get PAYE data at all.
3. **No window.** A Business Owner or accountant cannot see their jurisdiction's rules, rates, effective dates or the history of a change.
4. **The rulebook cannot be governed.** Roles, verification, source records, pending rates and notices (PR-GV-1 to PR-GV-8) have no home.

### 2.2 In scope
- Creating the Tax service `fish-tax` and moving the Tax context into it: the jurisdiction registry and currency and tax settings, VAT categories and rates, the corporate tax rule matrix, tax and VAT return computation and their audit, the rulebook change log, and PAYE (payroll tax) tables.
- The versioned read contract (T-PR-30), the design of the local read-through copy (T-PR-31), the migration and cutover plan, how Payroll consumes PAYE data, and the requirements for the Tax screen.

### 2.3 Out of scope
- **Posting is GL's** and stays there; Tax never writes a journal.
- **VAT amounts on a document** are calculated by the document's owner with the commons `VatCalculator`; Tax supplies the rate.
- **The Tax screen itself** is built by the FiSH+ER WEB session; **operator rulebook screens** belong to Omniview (section 7.4).
- **Building any of this before CM confirms.** This playbook is design; CM provisions the repo, infrastructure, CI and secrets once it has the name and the first two docs.
- The 24 October VAT deliveries in GL (GL-T-29 and GL-T-30) are not touched or delayed.

### 2.4 Principles that bind this work
| # | Principle | Source |
|---|---|---|
| S1 | Posting never calls Tax synchronously; a Tax outage must not stop a sale. | TJ-NFR-7; Policy Resolution PR-TX-1 |
| S2 | One source of truth per fact: rates and rules exist in Tax; everyone else holds a read-only copy or reads through the contract. | Decisions Log 2026-10-18 |
| S3 | A contract change is additive and nullable; every consumer's strict mirror declares a new field before the provider sends it; unknown keys are never tolerated. | Platform contract policy; Decisions Log 2026-09-29 |
| S4 | No currency literal anywhere; a default comes from the Company's tax jurisdiction. | Femi D-4, D-5 |
| S5 | Only CM pushes, merges and deploys. | Decisions Log |
| S6 | Every piece of work cites the requirement and use case it serves. | Decisions Log 2026-10-22 |

## 3. Plan (P)

### 3.1 Decisions (the answer to each open question of the 2026-09-19 design)

| # | Question | Decision |
|---|---|---|
| Q1 | Period selection | Tax reads net income by **date range** from GL's existing `?from=&to=` form (spans periods); no `periodId` form. |
| Q2 | Sharing `Jurisdiction` | The **registry is Tax-owned data**. Company holds a jurisdiction code and reads the registry. No duplicated enum and no entry in `fish-common`. |
| Q3 | Destination, name, stack | **`fish-tax`** (Femi, 2026-10-22). GitHub repo `fish-tax` (private), local folder `TX/`, Kotlin package `com.theprodeogroup.tax`, Kotlin, Ktor, Exposed, Flyway, Postgres, JSON logging with `requestId`, `/health`. Proposed host `tax-api.theprodeogroup.com` (CM decides), own database (proposed `tax_production`, CM decides), own ECS service, ALB and Jenkins job. |
| Q4 | Service-account authentication | The proven Cognito service-account pattern: one new account **Tax to GL** (read ledger figures) and, for every service that calls Tax, a service account **caller to Tax**. Human callers (WEB) use the user's token through the existing membership check (EA `GET /me`). |
| Q5 | WEB cutover | WEB reads Tax directly for the window (section 7) and repoints existing rate and jurisdiction reads by changing a base URL, because the contract is the same before and after (TS-1). |
| Q6 | Database | Its own database, as every extracted service has. |
| Q7 | `ManagedModule.TAX` | Stays an EA access grant; Tax authorises a human caller through the membership check, as POP, SOP and IM do. |
| Q8 (new) | Where VAT rates and returns live | **Tax** (Femi, 2026-10-22). GL keeps only a read-through copy of the rate windows (TS-4). |
| Q9 (new) | PAYE | **Tax provides payroll tax tables** (bands, thresholds, contribution rates, currency, effective windows); Payroll consumes them and keeps the computation (section 8). This supersedes PQ-15's interim answer. |

### 3.2 Requirements (SRS)

| ID | Requirement | Owner | Pri | Task |
|---|---|---|---|---|
| TS-1 | **The Tax read contract.** Tax exposes a versioned read contract published in `fish-contracts` (section 3.3). GL implements it as the interim provider from the first day; on extraction only the provider changes. Every read carries a `rulebookVersion` integer. | Tx, GL | M | T-TS-04 |
| TS-2 | **Registry.** The jurisdiction registry (code, name, legal currency, currency status, tax word, availability per capability) is Tax's. Company creation reads it. Ghana appears with no currency and stays Planned. | Tx | M | T-TS-09, T-TS-10 |
| TS-3 | **Rulebook governance.** Editor and verifier roles, immutable approved rows, source records, `pending` and `monitoring` states, correction rows and the impact query, the rulebook change log, last-reviewed dates, and notices (PR-GV-1 to PR-GV-8). The change log is `rulebook_change_log`, append-only. | Tx | M | T-TS-09 |
| TS-4 | **Local read-through copy (T-PR-31).** Any service whose hot path needs a rate (GL posting; later Payroll) holds a local copy of the rate window and never calls Tax synchronously. The design is section 3.4. | GL, Payroll | M | T-TS-12 |
| TS-5 | **Computation moves.** Corporate tax and VAT return computation and their audit records live in Tax. Tax reads net income by date range and VAT Control Account lines by direction from GL through a service account. | Tx, GL | M | T-TS-13, T-TS-14 |
| TS-6 | **Move, then remove.** Code and tables listed in section 3.5 move to `fish-tax` by the cutover sequence in section 3.6; GL deletes them only after a verified period. | Tx, GL, CM | M | T-TS-20, T-TS-21 |
| TS-7 | **PAYE.** Tax provides payroll tax tables through the contract; Payroll consumes them through its own read-through copy and keeps the computation (section 8). | Tx, Payroll | M | T-TS-16, T-TS-17 |
| TS-8 | **The window.** Tax provides the Tax screen requirements (section 7); WEB builds them; operator rulebook screens go to Omniview. | Tx, WEB, Omniview | M | T-TS-18, T-TS-19 |
| TS-9 | **Do not delay GL.** Nothing in this plan edits files GL has claimed for the 24 October VAT deliveries. GL introduces the single rate-lookup port (T-TS-03) in its own time. | GL | M | T-TS-03 |
| TS-11 | **Tax-types catalogue.** For each jurisdiction (UK, IE, NG, SL, LR, GN, CI) Tax holds a catalogue of **every tax type that applies**, not only VAT and corporate tax: VAT, GST or TVA; PAYE (employee income tax withheld by the employer); employee and employer social contributions; **self-employed** taxes (sole-trader income tax and the self-employed social contributions, such as Class 2 and Class 4 National Insurance in the UK, PRSI Class S in Ireland, and the equivalents elsewhere); corporate income tax; capital gains; withholding taxes; payroll levies; and any other tax a small business or its owner meets. Each entry has the local name, the payer, the authority and filing channel, the filing and payment periods, the headline rates, bands and thresholds by effective window, a status (`VERIFIED`, `UNVERIFIED` or `CONFLICT`) and a `volatile` flag. It is served by one read (section 3.3) and shown in the Tax window (W-TX-9). | Tx | M | T-TS-24, T-TS-25 |
| TS-13 | **Tax years.** (a) The **tax-year definition** per jurisdiction (start and end rule, for example the UK's 6 April to 5 April and Ireland's calendar year; the others are researched, not assumed) is Tx-owned data, distinct from a Company's own `fiscalYearStartMonth` in GL and from a company's accounting period. (b) For each jurisdiction and each tax year Tx gives the rates, bands, allowances, thresholds, contribution rates and filing deadlines in force, from 2024/25 onward as sources allow. (c) A **mid-year change** is shown as an effective window inside the year (date and new figure), never as a separate year. (d) A read **by tax year** sits beside the `asOf` read, and both answer from the same effective-dated rows, so they cannot disagree. (e) The Tax window has a tax-year selector (W-TX-10). The personal tax year, the corporate filing year and the Company's accounting year are three different things and are labelled as such. | Tx | M | T-TS-24, T-TS-25, T-TS-27 |
| TS-14 | **Standing maintenance.** Tx maintains the tax context for **every jurisdiction in the registry**, not only the first market, and for any added later. Each row (rate, band, threshold, allowance, contribution rate, filing deadline, tax-year definition, catalogue entry) carries a status (`VERIFIED`, `UNVERIFIED`, `CONFLICT`), a `verifiedOn` date and a `reviewBy` date. Each jurisdiction has an authority watch list, a calendar of known change events, and a defined path from a detected change to a published, verified row (section 3.10). A row not reviewed by its date is **flagged**, not silently trusted. | Tx | M | T-TS-28, T-TS-29, T-TS-30 |
| TS-15 | **Business Owner confirmation.** The Business Owner watches their own tax authority for changes and confirms, per Organisation, that each published row applies to them. Tax records each confirmation as an audit-trail event (who confirmed which row version, when). A row that is `UNVERIFIED`, or that has changed since the Organisation last confirmed it, shows a visible flag in the Tax window. Flags never block a computation or a posting. Tx still verifies its own rows against sources (accuracy is FiSH's onus); the owner confirms applicability and watches for change (section 3.11). | Tx, WEB, EA | M | T-TS-31, T-TS-32, T-TS-33 |
| TS-16 | **Time zone per jurisdiction.** The registry carries an IANA `timeZone` for each jurisdiction (and an optional `timeZoneNote` where daylight saving applies), as Tx-owned data like the tax-year definition. It is the Company's local business date: HR's approval and leave dates (FR-HR-17) and any service that must not use the server clock read the Company's jurisdiction from GL and the zone from the registry. Additive to GL's jurisdictions shape; GL hosts the copy (GL-T-36). The zones are data in the governed rulebook, changed by the same write path; the first values are in section 3.3. | Tx, GL, HR | M | T-TS-34 |
| TS-12 | **Scaffold.** `fish-tax` follows the package layout, build, auth and delivery conventions of its siblings (section 3.8) so CM can prepare CI and the `TX/` submodule path. | Tx, CM | M | T-TS-07 |
| TS-10 | **Operations.** Tax emits JSON logs with a `requestId`, has a real `/health`, per-service database, rate limiting on writes, backup and restore documented, and graceful shutdown, matching the platform readiness findings. | Tx, CM | S | T-TS-07, T-TS-06 |

### 3.3 The read contract (T-PR-30), specified

Paths are under Tax's `/api`. All reads require a valid service-account token or a human token with the Tax module grant. Responses are strict JSON; fields are only ever added, as nullable. `rulebookVersion` increases whenever any approved row changes.

| Read | Purpose | Shape |
|---|---|---|
| `GET /api/jurisdictions` | The registry for company creation and the Tax screen | `{"rulebookVersion": 41, "jurisdictions": [{"code":"UK","name":"United Kingdom (including Northern Ireland)","currency":"GBP","currencyStatus":"ONBOARDED","timeZone":"Europe/London","timeZoneNote":"Observes daylight saving (BST, UTC+1, from the last Sunday of March to the last Sunday of October)","taxWord":"VAT","availability":{"companyCreation":"FULL","vat":"FULL","corporateTax":"FULL","payrollTax":"PARTIAL"}}]}`. Today's `GET /jurisdictions` is the first three fields; `currencyStatus`, `timeZone`, `timeZoneNote`, `taxWord` and `availability` are added (all additive, `timeZoneNote` nullable). **Time zones** (IANA names; the tz database is the authority and each value is entered and verified through the rulebook path like any row): UK `Europe/London` (daylight saving), IE `Europe/Dublin` (daylight saving), NG `Africa/Lagos` (UTC+1, none), SL `Africa/Freetown` (UTC, none), LR `Africa/Monrovia` (UTC, none), GN `Africa/Conakry` (UTC, none), CI `Africa/Abidjan` (UTC, none). A jurisdiction without a zone returns `timeZone: null` and a consumer treats the business date as unavailable, never as UTC. |
| `GET /api/jurisdictions/{code}/vat-categories?asOf=YYYY-MM-DD` | VAT categories and rates at a date | `{"jurisdiction":"UK","asOf":"2026-10-12","rulebookVersion":41,"vatScheduleConfigured":true,"categories":[{"category":"STANDARD","ratePercent":"20","effectiveFrom":"2011-01-04","pending":null},{"category":"REDUCED","ratePercent":"5","effectiveFrom":"1992-04-01","pending":null},{"category":"ZERO_RATED","ratePercent":"0","effectiveFrom":"1973-04-01","pending":null},{"category":"EXEMPT","ratePercent":null,"effectiveFrom":"1973-04-01","pending":null}]}`. Today's GL route returns the first four fields and `categories` with `category` and `ratePercent`; `effectiveFrom` and `pending` (the next enacted change, `{"effectiveFrom","ratePercent"}`) are added, and `rulebookVersion`. Only **verified** rows appear (PR-GV-4). The refusal when nothing is configured keeps today's shape (`vatScheduleConfigured: false`, empty categories). |
| `GET /api/jurisdictions/{code}/vat-categories/window?from=&to=` | A rate window for a read-through copy | the same category rows with every effective window overlapping the range, plus pending rows up to the horizon |
| `GET /api/jurisdictions/{code}/rules?asOf=` | The corporate rule matrix by tax type | `{"jurisdiction":"IE","asOf":"...","rulebookVersion":41,"rules":[{"taxType":"CORPORATE_INCOME_TAX","rateStructure":{...},"effectiveFrom":"...","sourceClass":"PRIMARY"}]}` (shape as `rate_structure` encodes today, exposed as JSON) |
| `GET /api/jurisdictions/{code}/payroll-tax?asOf=` | PAYE bands and contribution rates | section 8.2 |
| `GET /api/jurisdictions/{code}/rate-history?type=&from=&to=` | The rulebook change history for the window screen | rows of `{"changedOn","summary","effectiveFrom","sourceClass","supersedes"}`; no operator names (Prodeo is a landlord; role-level only) |
| `GET /api/jurisdictions/{code}/tax-types?asOf=` | **The catalogue of every tax type that applies in the jurisdiction (TS-11)** | `{"jurisdiction":"UK","asOf":"2026-10-22","rulebookVersion":41,"taxTypes":[{"code":"VAT","localName":"VAT","family":"TRANSACTION","payer":"BUSINESS","authority":{"name":"HMRC","channel":"Making Tax Digital for VAT"},"filing":{"frequency":"QUARTERLY","rule":"one month and seven days after the period end"},"headline":[{"label":"Standard rate","value":"20%","effectiveFrom":"2011-01-04"}],"status":"VERIFIED","volatile":false,"detailRead":"vat-categories"}]}`. `code` values: `VAT`, `CORPORATE_INCOME_TAX`, `PAYE`, `EMPLOYEE_SOCIAL`, `EMPLOYER_SOCIAL`, `SELF_EMPLOYED_INCOME_TAX`, `SELF_EMPLOYED_SOCIAL`, `CAPITAL_GAINS`, `WITHHOLDING`, `PAYROLL_LEVY`, `OTHER` (new codes are added, never repurposed; consumers declare a code before Tax sends it). `family`: `TRANSACTION`, `PROFIT`, `PAYROLL`, `PERSONAL`, `OTHER`. `payer`: `BUSINESS`, `EMPLOYEE`, `EMPLOYER`, `OWNER`. `detailRead` names the contract read that holds the detailed figures (`vat-categories`, `rules`, `payroll-tax`) or is null where the catalogue entry is information only. |
| `GET /api/jurisdictions/{code}/tax-years` | The tax-year definition and the years Tax has data for | `{"jurisdiction":"UK","rulebookVersion":41,"definition":{"startRule":"6 April","endRule":"5 April next year","label":"2026/27"},"years":[{"label":"2025/26","start":"2025-04-06","end":"2026-04-05","status":"COMPLETE"},{"label":"2026/27","start":"2026-04-06","end":"2027-04-05","status":"CURRENT"}]}` (`status`: `COMPLETE`, `CURRENT`, `ANNOUNCED`, `PARTIAL` when some figures are unsourced). |
| `GET /api/jurisdictions/{code}/tax-years/{year}/tax-types` | **The catalogue for one tax year** (`year` is the label, for example `2026-27` for the UK or `2026` where the year is a calendar year) | the same body as `tax-types?asOf=`, with `taxYear` in place of `asOf`, and each headline figure carrying its **effective windows inside the year**: `"headline":[{"label":"Standard rate","windows":[{"from":"2026-04-06","to":null,"value":"20%"}]}]`; a mid-year change appears as two windows. Filing deadlines for the year are included. Answered from the same rows as `tax-types?asOf=`. |
| `GET /api/rulebook-version` | Cheap version probe for cache refresh | `{"rulebookVersion": 41}` |

Computation routes (Tax calls GL): `POST /api/companies/{companyId}/tax` (corporate tax for a period or date range) and `POST /api/companies/{companyId}/vat-return` (VAT return for a filing period), keeping today's request and response shapes, with the audit record stored in Tax.

Operator writes (Omniview): create a draft row, verify, supersede, mark a review. Never exposed to a Tenant.

Refusal codes keep today's stable codes: `no_vat_rate_schedule`, `no_tax_rule`, `vat_category_not_supported`, `company_not_found`; new: `rulebook_unavailable` for a caller that asked for a rate window the copy cannot serve.

### 3.3a Contract status: what is built (2026-10-22)

First slice, in `fish-tax` branch `reads/contract-1`, with golden fixtures written by the service's own route tests into `fish-contracts/contracts/tax/`. All behind the same JWT authentication as the scaffold; nothing deploys until Femi's DNS, database and Jenkins steps.

| Read | Built as | Differs from the sketch in 3.3 |
|---|---|---|
| `GET /api/rulebook-version` | `{"rulebookVersion": n}` | none |
| `GET /api/jurisdictions` | GL's `code`, `name`, `currency` plus `currencyStatus`, `timeZone`, `timeZoneNote`, `taxWord`, `availability` and the top-level `rulebookVersion` | `availability` is **derived from the data that exists**, not stored: company creation is FULL for an onboarded currency, PARTIAL when the currency is not named (the creator names it), PLANNED for a reference-only currency; VAT is FULL only when a verified schedule exists; corporate tax and payroll tax are PLANNED until their rulebook tables are built |
| `GET /api/jurisdictions/{code}/vat-categories?asOf=` | GL's shape plus `rulebookVersion`, per-category `effectiveFrom` and `pending` (the next enacted change); percent strings; verified rows only; not-configured is `vatScheduleConfigured: false` with no categories | `asOf` defaults to today (UTC) and is echoed; a malformed value is 400 `invalid_as_of`; an unknown code is 404 `jurisdiction_not_found` |
| `GET /api/jurisdictions/{code}/tax-years` | `definitions` (one per kind, PERSONAL and CORPORATE, with `startRule`, `endRule`, `effectiveFrom`, `status`) and `years` from the first year starting in 2024, to next year, each with `timing` PAST, CURRENT or FUTURE | The year `status` of the sketch (COMPLETE, ANNOUNCED, PARTIAL) is **not** built: it would claim a completeness Tax cannot yet know. `timing` is purely about the date; data completeness arrives, additively, with the catalogue. Definitions are served marked VERIFIED, UNVERIFIED or CONFLICT; drafts and retired rows are never shown |

**Not yet built:** `tax-types` and `tax-years/{year}/tax-types` (the catalogue needs its own tables and the seeded research, T-TS-24/25/30), `payroll-tax`, `rate-history`, the computation routes, the confirmation routes. **Registry data:** V3 enters the IANA zones, tax words and the unchanged currency status for the seven original jurisdictions as the registry's initial reference data (like V1); moving the registry under the maker-checker write path, which TS-16 and T-TS-34 foresaw, is a later task, because the zones are objective facts in the IANA database and the tax words follow the research digest.

### 3.4 The local read-through copy (T-PR-31), designed

**The problem.** Posting a sale needs the VAT rate now. If GL called Tax for each posting, a Tax outage, deploy or slow response would stop every sale and purchase in the platform (S1, TJ-NFR-7).

**The design.**
1. **A narrow port.** GL introduces one rate-lookup port, `RateSource` (T-TS-03): `rateFor(jurisdiction, category, taxPointDate)`. The three posting use cases call only this port. Before extraction it is backed by GL's own `vat_rates` table. After extraction it is backed by the local copy. No posting code changes at cutover.
2. **A local copy, not a cache of responses.** GL keeps a table `tax_rate_copy(jurisdiction, category, rate_percent, effective_from, effective_to, pending, rulebook_version, fetched_at)`. In fact it is today's `vat_rates` table, kept as a read model that Tax now populates; GL stops writing it.
3. **Refresh, not request-time fetch.** A refresher in GL pulls `GET /api/rulebook-version`; if it changed it pulls `vat-categories/window` for each enabled jurisdiction and replaces the rows in one transaction. It runs on start, every 15 minutes, and on an optional manual trigger. The window it fetches runs from the earliest effective date any open document can have to **400 days ahead**, so a pending change is present before its effective day.
4. **Posting reads only the local copy.** If the copy has no row for the date, posting refuses with the existing `no_vat_rate_schedule` error (never a default, per the Decisions Log 2026-10-15), and logs that the copy may be stale.
5. **Tax down is fine.** The copy keeps serving. Rates are effective-dated facts; a rate in force on a date changes only by a correction, which the refresher picks up after Tax recovers.
6. **Staleness is visible, not blocking.** `fetched_at` and `rulebook_version` are on a GL admin read and in a metric; an alarm fires if `fetched_at` is older than one hour. Posting does not block on staleness.
7. **Corrections.** A correction row in Tax is a new effective-dated row. Because callers now compute VAT (GL sees an amount and a category, not a rate row), the **caller sends the basis** it used, `vatBasis { ratePercent, rulebookVersion, effectiveFrom }` (optional, consumer-first), and GL stores it beside the source reference, so the impact query (PR-GV-8) can list postings made under a superseded row (section 3.9).
8. **First deploy.** The table already holds the live rows; the first Tax export is compared with it row by row (T-TS-11) before GL switches its refresher on.

**Failure modes.**

| Event | Result |
|---|---|
| Tax unreachable for hours | Posting continues from the copy; alarm after one hour stale. |
| Tax returns an unexpected shape | The refresher keeps the old copy, logs the error, alarms; strict decoding makes the break loud (S3). |
| A rate is corrected in Tax | The next refresh replaces it; earlier postings keep the row they used and appear in the impact report. |
| A jurisdiction is added or becomes available | Appears at the next refresh; a Company created in it before then waits at most the refresh interval. |
| Copy missing a date | `no_vat_rate_schedule`; nothing is posted. |

**Who needs a copy.** GL in phase one (it serves the rate facade, and, until GL-T-26b lands, its posting); Payroll (PAYE) in phase two (section 8). SOP, POP, CBB and IM read the rate through GL's facade (`GET /companies/{companyId}/vat-categories`, kept **until a caller holds its own copy**) and so inherit the copy; they move to reading Tax directly only if they need to. WEB reads Tax directly (online, display only).

### 3.5 What moves, what stays

| Moves to `fish-tax` | Stays in GL |
|---|---|
| Tables: `jurisdictions`, `tax_rules`, `tax_computations`, `vat_rates` (becomes Tax's source of truth; GL keeps a copy under TS-4), `vat_returns` | `companies` (with the jurisdiction **code**), `periods`, `journal_entries`, `journal_lines`, the VAT Control Account and all postings |
| `domain/tax/*` (rule, type, rate structure, computation, rate schedule, filing period, return, repositories, ids; **`VatCategory` and `VatLineDirection` go to `fish-common`**, section 3.9; the return takes plain VAT-line records, not GL's journal types), `ComputeTaxUseCase`, `ComputeVatCategoriesUseCase`, `ComputeVatReturnUseCase`, `TaxRoutes`, `VatCategoriesRoutes`, `VatReturnRoutes`, `JurisdictionRoutes`, the Exposed repositories, `rate_structure_encoding`, tests | The three posting use cases (they call the `RateSource` port), the profit-and-loss report route, the VAT-control-line read (new, TS-5), `ManagedModule.TAX` (tenancy), the VAT calculator input (the document owner's job) |
| Migrations V5, V9, V25, V29, V30, V31, V34 become a **fresh baseline** in `fish-tax` (new repo, new database), seeded by an export, not a literal copy of history | The migrations stay as GL's history; GL later adds one that removes the moved tables |
| New: roles, `rulebook_change_log`, availability, `pending` and `monitoring` states, source records, correction rows | |

Foreign keys on `tax_computations` and `vat_returns` to `companies` and `periods` do not cross a database boundary; they become plain UUID columns with the Company checked through the membership and company reads.

### 3.6 Migration and cutover plan

Each step is reversible, and only CM pushes, merges and deploys.

| Step | What | Rollback | Gate |
|---|---|---|---|
| 0 | GL introduces the `RateSource` port, backed by its own table (T-TS-03). Contract fixtures are published, GL serving them (T-TS-04). | revert the port | CM confirms; GL's 24 October work has landed |
| 1 | CM creates the repo, infrastructure, CI and secrets. `fish-tax` is scaffolded and deployed empty with `/health`. | tear down | name decided (done) |
| 2 | Export GL's tax tables; seed `fish-tax`; run the row-by-row comparison (T-TS-11). Tax is read-only and shadows GL. | delete Tax's data | comparison clean |
| 3 | GL's refresher reads Tax; the table becomes the copy; GL's own write path is switched off. A feature flag on the `RateSource` implementation. | flip the flag back; GL's table is still the source | Tax stable for a week; alarm tested |
| 4 | WEB and consumers repoint reads (base URL change). | repoint back | contract tests green |
| 5 | Operator writes move to Tax (Omniview). GL's write routes removed. | restore the routes from the previous release | change log verified |
| 6 | Computation routes move; Tax calls GL's read routes. GL keeps a facade that answers 410 with a pointer for one release (except `vat-categories`, which stays as the rate facade until every caller has its own copy, section 3.9). | route back | return reproduced for a known period |
| 7 | After an agreed period, GL removes the moved code and tables (T-TS-21), with CM. | none (restore from backup) | Femi's go |

### 3.8 The first scaffold of `fish-tax` (for CM: CI and the `TX/` submodule path)

Mirror POP, the closest sibling (Kotlin, Ktor, Exposed, Flyway, Postgres); CM copies POP's `build.gradle.kts`, `Dockerfile`, `Jenkinsfile` and `settings.gradle.kts` as the starting point and sets the names.

| Item | Value |
|---|---|
| Repo, path | `fish-tax` (private); submodule path `TX/` in the FiSH superproject |
| Root layout | `build.gradle.kts`, `settings.gradle.kts`, Gradle wrapper, `Dockerfile`, `Jenkinsfile`, `README.md`, submodules `common/` (`fish-common`) and `contracts/` (`fish-contracts`), as POP has |
| Main class | `com.theprodeogroup.tax.infrastructure.web.ApplicationKt` |
| Package layout | `com.theprodeogroup.tax.domain` (`jurisdiction`, `rulebook` for rates, rules, payroll tax and the tax-types catalogue, `computation` for tax computation and VAT return), `com.theprodeogroup.tax.application` (use cases), `com.theprodeogroup.tax.infrastructure.web` (routes, DTOs, `Application.kt`, `Auth.kt`), `...infrastructure.persistence` (Exposed tables and repositories), `...infrastructure.audit` (the change log writer), `...infrastructure.ea` (membership gateway and `TaxMembershipAuthorizer`), `...infrastructure.gl` (read client for net income and VAT control lines, with its service-account token provider), `...infrastructure.notification` (rate-change notices through EA) |
| Resources | `logback.xml` (JSON with `requestId`), `db/migration/V1__baseline.sql` (the fresh baseline of section 3.5), later versions numbered from V2 |
| Tests | `src/test` (domain and application), `src/integrationTest` (real Postgres, as POP) |
| Auth | Cognito JWT for human callers, with the membership check (EA `GET /me`) and the module grant `TAX`; service-account providers for each caller (GL, SOP, POP, CBB, IM, Payroll, EA, Omniview) named `FISH_JWT_SERVICE_AUTH_NAME_*`; service-account calls bypass the membership check by design |
| Configuration | Database URL and credentials from Secrets Manager; EA base URL; GL base URL and the Tax-to-GL service-account credentials; no secret in code or in the repo |
| Endpoints in the first scaffold | `/health` (real: database reachable), then `GET /api/jurisdictions` (reads the baseline), so the pipeline deploys something real before the rulebook is ported |
| Sequence | CM prepares CI and `tax.tf`; Tx lands the scaffold (T-TS-07) as the first commit, on a branch, handed to CM; CM merges and deploys |

### 3.10 Standing maintenance: who watches, how a change is published, how long a row may go unreviewed (TS-14)

**Who owns it.** (Amended by section 3.11: the Business Owner watches their own authority and confirms the rows apply to them; Tx keeps FiSH's rows accurate. The process below is how Tx keeps them accurate.) The Tax Jurisdiction session (Tx) owns keeping each jurisdiction's published rows current and accurate. It proposes (editor); the verifier (Femi, until he delegates, PR-GV-1) approves. Prodeo is a landlord (Decisions Log 2026-10-15): this is the platform's own reference data, never a Tenant's. Where Tx is not available, CM records the gap; nothing is auto-published.

**What is watched, per jurisdiction.** A watch list lives with the rulebook (data, not code): the authority pages and the gazettes or Finance Acts that announce changes, the statutory instruments, and the dates of known events. The starting lists come from the research digest section 5 and the per-country docs, for example: UK: HMRC rates-and-thresholds pages, the Budget and Finance Act, employer rates pages each January and March; Ireland: Revenue tax-and-duty manuals and eBriefs, the October Budget, the Finance Act, the Department of Social Protection PRSI guides (PRSI steps each 1 October); Nigeria: Nigeria Revenue Service notices, the gazette, ministerial guidelines and the Withholding Tax Regulations; Sierra Leone: National Revenue Authority notices and the Finance Act each November or December; Liberia: Liberia Revenue Authority notices and tax amendment acts; Guinea: the finance law and the Directorate General of Taxes; Cote d'Ivoire: the finance annex each December.

**Known events calendar** (a per-jurisdiction table of dated checks): UK 6 April (tax year), 1 April (minimum wage, Corporation Tax financial year), the Autumn Budget; Ireland 1 January, 1 October (PRSI), the October Budget; Nigeria 1 January (regime year), notices as issued; Sierra Leone, Liberia, Guinea, Cote d'Ivoire: the finance law each year-end and any mid-year amendment. The calendar creates a review task before each event.

**From a detected change to a published row.**
1. A change is detected (a watch-list page changes, a calendar event, a consumer or Tenant report).
2. The editor enters a **draft** row with the instrument, URL, source class, and the effective window (`pending` if enacted ahead of its date, `monitoring` if only proposed).
3. The verifier checks the source, records primary or a recorded professional judgment (PR-GV-4), and approves; the row becomes `VERIFIED` with `verifiedOn`.
4. The rulebook version increases; consumers' copies refresh; the Tax window and, for a pending row, the owner notice follow (PR-GV-6).
5. The change log records requester, verifier, time, source and the before and after.

**How long a row may go without review (proposed thresholds, configuration data; Femi can change them).**

| Condition | Flag | Where it shows |
|---|---|---|
| A draft or `UNVERIFIED` row older than **14 days** | amber "awaiting verification" | the verifier's queue |
| A `VERIFIED` row past its `reviewBy` date (default **90 days**, the quarterly review of PR-GV-7) | amber "review due" | the verifier's queue |
| A row marked `volatile` past **30 days** | amber "review due" | the verifier's queue |
| A row past **180 days** unreviewed, or any `CONFLICT` row | red "may be out of date" | the verifier's queue and the Tax window (W-TX-9 status mark) |
| A calendar event reached with no review done | red "event not reviewed" | the verifier's queue |

A flag never blocks a computation by itself (a `VERIFIED` row stays usable until the verifier withdraws it); it makes the staleness visible to the verifier and, past 180 days, to the owner. A row that is `UNVERIFIED` or `CONFLICT` is not used in a computation (PR-GV-4).

**Where the catalogue comes from.** The per-country catalogue is seeded from the researchers' findings (research digest section 5), each row with its source class and status exactly as reported, and nothing seeded as `VERIFIED` until the verifier approves it. Rows the researchers could not verify are seeded `UNVERIFIED` or `CONFLICT`, never filled in. The UK and Irish PAYE, NIC, PRSI and USC figures by tax year; Nigeria's 2026 regime; and the Mano River catalogue (when reported) are the first seed.

**Seed status (2026-10-22).** The research for all seven jurisdictions is in digest section 5 (5.1 UK, 5.2 Ireland, 5.3 Nigeria, 5.4 Sierra Leone, Liberia, Guinea and Cote d'Ivoire), each row with its source class. The Mano River work also settled several conflicts with the country docs: the Sierra Leone PAYE unit (NLe) and corporate rate (30% verified), the Liberian PAYE bands, NASSCORP split and GST date, the Guinea corporate tiers, and the Ivorian CMU. T-TS-30 seeds from it.

## Open items inside maintenance
- **Who is the second pair of eyes when Femi is unavailable** is Femi's to decide when he delegates the verifier role; until then verification waits (it does not self-approve).
- The thresholds above, the watch lists and the events calendar are Tx's proposals, to be confirmed at approval.

### 3.11 Who watches the authority, and the Business Owner's confirmation (TS-15)

**Femi's answer (logged, 2026-10-22):** who watches each tax authority for changes is "The business owner". This sits with two standing rules: FiSH prepares and analyses and the Tenant owns its records and answers to its authority ("preparation is not audit", Decisions Log 2026-10-16), and the accuracy of what FiSH publishes is FiSH's onus.

**Reconciling them: two different duties.**

| Duty | Whose | What it means |
|---|---|---|
| The rows FiSH publishes are accurate | **FiSH (Tx)** | Tx checks each row against its source, records the source and class, marks it `VERIFIED`, `UNVERIFIED` or `CONFLICT`, dates it, and corrects it when told or when it finds it wrong. Tx does not promise to be the Tenant's early-warning service for every authority announcement; section 3.10 is how Tx keeps its own rows accurate. |
| Watching the authority for changes that affect the business | **The Business Owner** | The owner is the party who answers to the authority and who knows their own situation. They watch announcements from their authority and tell FiSH when a published row no longer matches. |
| Confirming a published row applies to this business | **The Business Owner** (per Organisation) | A row can be correct and still not apply (a small business below a threshold, a sector rate). The owner confirms, and the confirmation is recorded. |
| What the business actually files | **The Business Owner** | FiSH prepares figures from the Tenant's records and the confirmed rows; the Tenant files and is audited. |

**The confirmation record (an audit-trail event).** `tax_row_confirmations(id, tenant_id, company_id, jurisdiction, row_key, row_version, confirmed_by, confirmed_at, note)`:
- `row_key` identifies the rule (for example `VAT/STANDARD`, `PAYE/bands`, `SELF_EMPLOYED_SOCIAL/class4`); `row_version` is the rulebook row version confirmed (the immutable approved row, PR-GV-2), so "changed since confirmed" is exact.
- Written only by a caller authorised at that Organisation through the EA membership check; for the first release, the Organisation's Owner Admin (RBAC is frozen until the Live switch, so no new delegation model). Append-only; a re-confirmation is a new event.
- Read by the same Tenant only. Tax holds tenant-scoped data in this one table; it is scoped by `tenant_id` and `company_id` at the application layer like the sibling services, and is included in the platform's tenant-isolation scope (`docs/Database_Tenant_Isolation_RLS_Scope.md`). Prodeo operators do not read it.
- The event is also written to the Organisation's audit trail as "Business Owner confirmed [rule] as at [date]".

**Flag rules (what the owner sees, and when).** All thresholds are configuration data.

| State | Flag the owner sees | When it appears |
|---|---|---|
| Row is `UNVERIFIED` or `CONFLICT` | amber **"FiSH has not verified this yet"** (and the source note) | from the moment the row is visible; not used in any computation |
| A row was `VERIFIED` and has since changed (a new approved row, a correction, a new effective window) and the owner has not confirmed the new version | amber **"Changed on [date]: please review and confirm"** with the old and new figures and the effective date | when the new row is published, even while it is `pending`; a reminder 7 days before its effective date (PR-GV-6) |
| Same, and the effective date has arrived with no confirmation | red **"In use since [date], not yet confirmed by you"** | on the effective date |
| A standing row the Organisation has never confirmed | grey **"Not confirmed by you"** | after the Organisation's first posting that uses it, and a reminder 30 days later |
| A confirmation older than 12 months | grey **"Confirm again for the new tax year"** | at the start of the jurisdiction's tax year (TS-13) |
| A row Tx flags as `may be out of date` (3.10, 180 days or `CONFLICT`) | red **"FiSH has not re-checked this for [n] days"** | as in 3.10 |

A flag never stops a posting, a computation or a return. It informs; the owner decides. A "Report a problem" action on any row puts the row in the verifier's queue (3.10) and records who reported it.

**What the Business Owner sees (the Tax window, W-TX-11).** A list "Rules I rely on" for the Organisation: each rule that applies (VAT rates, PAYE, social contributions, self-employed taxes, corporate tax), with the figure and effective date, the status chip (`VERIFIED on [date]` with the source class, or `NOT VERIFIED`), the flag from the table above, the old and new figure when changed, a link to the authority's own page, a **"Confirm this applies to us"** button, a **"Report a problem"** button, and the Organisation's own confirmation history. A summary at the top: "N rules to review, M changed since you last confirmed." Phone-first and compact (the WEB layout checklist).

**Wording for Femi's approval (plain words, shown in the Tax window and in onboarding).**
- "FiSH publishes the tax rules for your country. For each one we show where it came from, when we last checked it, and whether we have verified it."
- "You answer to your tax authority. Please watch your authority's announcements, and confirm here that each rule applies to your business. When a rule changes we will tell you, and show you what changed."
- "If something looks wrong, tell us and we will check and correct it. We prepare your figures from your records and these rules; you remain responsible for what you file."

**Open points for Femi (docs only; nothing built).**
1. Whether the owner's confirmation is per Organisation (proposed) or per Tenant.
2. Whether a delegate (an accountant with APPROVE) may confirm; proposed no for the first release (RBAC freeze), Owner Admin only.
3. The reminder intervals (7 days before, 30 days after first use, 12 months) and whether "red on the effective date" is the right escalation.
4. Whether Tx should also offer an optional change-alert service (a digest when Tx's own watch finds a change) as a courtesy; proposed yes, clearly marked as not a substitute for the owner's own watch.

### 3.9 GL's view, and Tx's answers (source: `Playbooks/GL/GL_Tax_Extraction_GL_View.md`, GL session, 2026-10-22)

GL read this plan against its code and added four findings. Tx accepts all of them; the plan above is amended as follows.

| # | GL's point | Tx's answer and the amendment |
|---|---|---|
| 1 | After GL-T-26b callers (SOP, POP, CBB) compute VAT, so GL's posting reads no rate; the "never call Tax while posting" guardrail now bites on the callers. | **Agreed.** Section 3.4 is amended: the read-through copy serves GL's `vat-categories` facade, and the callers read their rate from that facade. |
| Q1 | Keep GL's `vat-categories` facade until a caller has its own copy, rather than for one release? | **Yes.** The facade stays until a caller holds its own copy, not on a fixed date. The callers already need GL to be up to post, so reading the rate from GL adds no dependency, and Tax can be down for hours without stopping a sale. Cutover step 6 (section 3.6) no longer says "one release". |
| Q2 | Accept an optional `vatBasis { ratePercent, rulebookVersion }` on VAT-bearing postings, so the impact query (PR-GV-8) is possible? | **Yes.** Point 7 of section 3.4 (the posting records the rate row it used) is replaced: the caller sends the basis and GL stores it. Tx asks for one more optional field, `effectiveFrom` (the effective date of the rate row used), so the row is identified exactly: `vatBasis { ratePercent, rulebookVersion, effectiveFrom }`, all optional, consumer-first. |
| 2 / Q3 | `VatCategory` and `VatLineDirection` are vocabulary GL writes into the ledger; they cannot come from `fish-tax`. Move them to `fish-common` (GL-T-33) in place of "domain/tax moves" for those two types? | **Yes.** Section 3.5's "domain/tax/*" row is amended: those two enums are the exception and live in `fish-common`, beside `VatCalculator`, unchanged. Adding a value is a contract change declared by consumers first. Tax-types catalogue codes (TS-11) are Tax's own and stay in `fish-tax`. |
| 2 | `VatReturn.of` takes GL's `JournalEntry` and `JournalLine`; Tx must not depend on GL's domain. | **Agreed.** Tax's port takes plain VAT-line records (below); the classification moves with the function and its tests. |
| Q4 | Raw VAT-line records, or a pre-classified list? | **Raw.** One rule, Tax's, classifies, exactly as `VatReturn.of` does. Tx needs from `GET /companies/{companyId}/vat-lines?from=&to=` (GL-T-32): entry id, entry date, side, amount, currency, the raw `VAT_DIRECTION` tag (possibly absent), the `VAT_CATEGORY` tag, the source reference, and entry status "posted or reversed" only (the `affectsBalance` rule). |
| Q5 | Company creation: a copy of the registry in GL, or a synchronous read with a fallback? | **A copy.** GL keeps its small `jurisdictions` table as a copy refreshed with the rate window. Tx asks that the copy carry `code`, `name`, `enabled`, `currency`, plus the additive `currencyStatus` and the `companyCreation` availability, so GL can refuse creation in a Planned jurisdiction (PR-LC-3) without a call to Tax. |
| 3 | The `RateSource` port is smaller than planned (after T-26b only the legacy path calls it). | **Agreed;** T-TS-03 is GL-T-34. |
| 4 | The settlement door (`vat-settlement`) stays in GL because it posts. | **Agreed.** Tax's return gives the net due; CBB or WEB records the payment through GL; the next return excludes the SETTLEMENT-tagged lines. |
| 5 | Order: the 24 October VAT work first, then T-33 (enums to common), T-34 (port), T-35 (contract fixtures), T-32, T-36 (refresher), deletion last. | **Agreed.** Mapped below. |

One point Tx raises back. GL says the closed `Jurisdiction` enum stays where it is. The registry migration (`V29__jurisdictions.sql`, Femi 2026-10-05) records the opposite decision: jurisdiction is reference **data** that can be added without a code change or deploy, replacing the compiled enum. The plan follows the 2026-10-05 decision (Tax-owned registry, Company holds a code). If GL's `Jurisdiction` enum is still compiled anywhere, GL should treat it as legacy to remove, not as a vocabulary other services must copy.

**Mapping of GL's tasks to this plan.** GL-T-33 (enums to `fish-common`) and GL-T-34 (the port) = prerequisites of T-TS-03; GL-T-35 (serve the contract fixtures) = T-TS-04; GL-T-32 (VAT-line read) = T-TS-13; GL-T-36 (refresher, admin read, jurisdictions copy) = T-TS-12. T-TS-12 now includes the `jurisdictions` copy for Company creation.

## 4. Use cases (U)

| ID | Use case | Serves |
|---|---|---|
| UC-TS-1 | **A sale is posted while Tax is down.** GL reads the VAT rate from its local copy for the tax point date and posts; Tax's outage is invisible. If the copy lacks the date, the posting is refused with `no_vat_rate_schedule` and nothing posts. | TS-4 |
| UC-TS-2 | **A rate is enacted ahead of its date.** The verifier approves a `pending` row; the next refresh puts it in GL's copy; on its effective date postings use it with no deploy; the owner sees the banner and the notice. | TS-3, TS-4 |
| UC-TS-3 | **A wrong rate is corrected.** Tax supersedes the row; the refresh replaces it; the impact query lists postings made under the old row. | TS-3 |
| UC-TS-4 | **A new jurisdiction is added.** The operator adds it disabled, adds its currency, rates and rules, the verifier approves, availability moves to Partial then Full; it appears in company creation at the next refresh. | TS-2, TS-3 |
| UC-TS-5 | **An accountant runs a VAT return.** The accountant picks a filing period in the Tax screen; Tax reads VAT Control Account lines by direction from GL for the period, computes output, input and net due, stores the audit record and shows the result. | TS-5 |
| UC-TS-6 | **An accountant computes corporate tax for a period.** Tax reads net income for the period's dates from GL, applies the rule in force (splitting a straddling period for the UK and Ireland, flagging the others), stores the computation. | TS-5 |
| UC-TS-7 | **Payroll computes PAYE.** Payroll reads the bands and contributions for the Company's jurisdiction from its copy and computes; if the rule is unverified or the copy lacks the date, it refuses with a plain message. | TS-7 |
| UC-TS-8 | **A Business Owner opens the Tax window.** The owner sees their jurisdiction, currency, the tax word, what is available, the VAT categories and rates with effective dates, the next change, the history and the PAYE tables. | TS-8 |
| UC-TS-9 | **Cutover step 3 fails.** The flag is flipped back; GL reads its own table; no posting is lost. | TS-6 |
| UC-TS-11 | **A budget changes a rate.** The calendar reaches the Irish October Budget; Tx reviews the announced measures, enters `monitoring` rows for what is only announced and `pending` rows for what is enacted; the verifier approves what has a source; consumers refresh. | TS-14 |
| UC-TS-12 | **A jurisdiction goes stale.** A jurisdiction's rows pass their review dates; the verifier's queue turns red for it; the Tax window shows "may be out of date" against the affected rows; Tx reviews and the flags clear. | TS-14 |
| UC-TS-13 | **The Business Owner confirms a rule.** The owner opens "Rules I rely on", reads the Standard VAT rate row, taps Confirm; Tax records the confirmation (who, which row version, when) and the flag clears. | TS-15 |
| UC-TS-14 | **A rate changes after the owner confirmed.** A new row is published as `pending`; the owner's row shows "Changed on [date]: please review and confirm" with old and new figures; a reminder 7 days before; if still unconfirmed on the effective date it turns red; the owner confirms or reports a problem. Postings are never blocked. | TS-15 |
| UC-TS-15 | **The owner reports a wrong rule.** The owner taps Report a problem on a row; it goes to the verifier's queue with who reported it; Tx checks the source, corrects by a superseding row if wrong (PR-GV-8) or replies with the source if right. | TS-15, TS-14 |
| UC-TS-10 | **Tax is deployed during a sale.** The refresher sees a transient error, keeps the copy, retries; no user effect. | TS-4 |

## 5. Tasks (T)

Sizes are working days. Owners are sessions; Tx builds in its own `TX/` checkout once CM confirms. This list expands T-PR-30 to T-PR-32.

| ID | Task | Owner | Days | Depends on |
|---|---|---|---|---|
| T-TS-01 | This playbook; Q3 recorded in `Tax_Extraction_DDD_Design.md` | Tx | done | none |
| T-TS-02 | Route the Tax window requirements to FiSH+ER WEB and the operator screens to Omniview via CM | Tx | 1 | T-TS-01 |
| T-TS-03 | `RateSource` port in GL, posting use cases call only the port; behaviour unchanged | GL | 2 | CM confirm; GL's 24 Oct work landed |
| T-TS-04 | Tax read contract fixtures in `fish-contracts` (section 3.3), consumer-first; GL serves them as interim provider (T-PR-30) | Tx, GL | 4 | CM confirm |
| T-TS-05 | Rulebook change log and roles inside GL's tax package (T-PR-05 to T-PR-07) | GL, Tx | 6 | T-TS-03 |
| T-TS-06 | Repo `fish-tax`, infrastructure plan (Terraform, ECR, Jenkins job, Cognito service accounts, database, ALB) | CM | CM | name (done), T-TS-01 |
| T-TS-07 | Scaffold: Gradle, Ktor, Exposed, Flyway baseline, auth (JWT and service account), membership check, `/health`, JSON logs, CI | Tx | 4 | T-TS-06 |
| T-TS-08 | Port `domain.tax` and tables with their tests into the fresh baseline; foreign keys become plain UUIDs | Tx | 6 | T-TS-07 |
| T-TS-09 | Rulebook write path, roles, source records, `pending` and `monitoring`, correction rows, impact query, change log (PR-GV-1 to -8) | Tx | 8 | T-TS-08 |
| T-TS-10 | Implement the read contract routes (section 3.3) | Tx | 5 | T-TS-08, T-TS-04 |
| T-TS-11 | Export from GL, seed Tax, row-by-row comparison script | Tx, GL | 3 | T-TS-10 |
| T-TS-12 | GL read-through copy and refresher, alarm, admin read, and the `jurisdictions` copy for Company creation (T-PR-31 build; GL-T-36) | GL | 5 | T-TS-03, T-TS-10 |
| T-TS-13 | GL: the VAT-line read with raw fields for Tax (`GET /companies/{companyId}/vat-lines?from=&to=`, GL-T-32); P&L `?from&to` already exists | GL | 2 | CM confirm |
| T-TS-14 | Tax computation routes (corporate tax, VAT return) reading GL; audit records | Tx | 6 | T-TS-10, T-TS-13 |
| T-TS-15 | Consumers read through the contract: SOP, POP, CBB, IM, WEB (base-URL changes) | each | 1 each | T-TS-12 |
| T-TS-16 | Payroll: PAYE read and read-through copy; remove its unpopulated `PayrollTaxRule` storage (extends T-TJ-09) | Payroll | 4 | T-TS-10, T-TS-17 |
| T-TS-17 | PAYE data: seed UK, IE, NG, GN, CI, LR, SL from the country tax docs and YAML, each row with source class; SL threshold unit and LR NASSCORP conflict stay `unverified` | Tx | 4 | T-TS-09 |
| T-TS-18 | WEB: Tax window screens (section 7), through FiSH+ER WEB | WEB | per screen | T-TS-10 |
| T-TS-19 | Omniview: operator rulebook screens (enter, verify, supersede, review, impact) | Omniview via CM | per screen | T-TS-09 |
| T-TS-20 | Cutover steps 2 to 6 with rollback (section 3.6) | CM, Tx, GL | 5 | T-TS-11, T-TS-12, T-TS-14 |
| T-TS-21 | Remove moved code and tables from GL after the verified period | GL, CM | 3 | T-TS-20, Femi's go |
| T-TS-22 | Golden and contract tests; the strict-decoding mirror in each consumer | Tx and each consumer | with each | T-TS-04 |
| T-TS-23 | README, operator sheet, update the extraction design doc | Tx | 2 | T-TS-14 |
| T-TS-24 | **Tax-types catalogue (TS-11, TS-13):** research and seed the catalogue for UK, IE, NG, SL, LR, GN, CI, including the self-employed taxes, each entry with authority, filing periods, headline figures by window and status, **organised by tax year from 2024/25 onward as sources allow, with each jurisdiction's tax-year definition**. Only the country docs' sections exist today (section 9); self-employed and the other taxes are researched in this task | Tx | 6 | T-TS-09 |
| T-TS-25 | Add the `tax-types` read to the contract fixtures, consumer-first, and implement it (extends T-TS-04 and T-TS-10) | Tx | 2 | T-TS-04 |
| T-TS-26 | Tax window: add W-TX-9 (taxes that apply) to the WEB handoff | Tx, WEB | 1 | T-TS-25 |
| T-TS-28 | **Maintenance data (TS-14):** the per-jurisdiction authority watch list and events calendar as data; the `verifiedOn`, `reviewBy`, `volatile` and status columns on every rulebook row; the review flags (the table in 3.10) computed from them | Tx | 4 | T-TS-09 |
| T-TS-29 | **Maintenance process:** the verifier's queue (awaiting, review due, may be out of date, event not reviewed) as an Omniview screen, with the thresholds as configuration | Omniview via CM, Tx | 3 | T-TS-28, T-TS-19 |
| T-TS-30 | **First maintenance cycle:** seed the catalogue for UK, IE, NG from digest section 5 (and the Mano River four when reported), each row with status and source class; run the first review round; record the calendar | Tx | 5 | T-TS-24, T-TS-28 |
| T-TS-31 | **Confirmation record (TS-15):** the `tax_row_confirmations` table, the write and read routes (`POST` and `GET /api/companies/{companyId}/tax-confirmations`) behind the EA membership check, the audit-trail event, fixtures consumer-first | Tx | 5 | T-TS-07, the first Company-scoped route |
| T-TS-32 | **Flag computation:** the owner-side flag rules (3.11) computed from row status, row version and confirmations; configuration for the intervals; the "changed since confirmed" diff | Tx | 3 | T-TS-31, T-TS-28 |
| T-TS-33 | **Window:** W-TX-11 "Rules I rely on" added to the WEB handoff; notices through EA for the reminders | Tx, WEB, EA | 2 | T-TS-32 |
| T-TS-34 | **Time zone (TS-16):** a `time_zone` and `time_zone_note` on the registry (a migration, no data in it), the values entered through the rulebook path, the additive field in the `jurisdictions` fixture consumer-first (HR2 and GL declare it first), and the copy in GL's registry copy (GL-T-36) | Tx, GL, HR | 2 | T-TS-09, T-TS-04 |
| T-TS-27 | **Tax years (TS-13):** the tax-year definition table and the two by-year reads in the contract fixtures, consumer-first; implement from the same effective-dated rows; W-TX-10 added to the WEB handoff | Tx, WEB | 3 | T-TS-24, T-TS-25 |

## 6. Order (O): foundations before features

- **Wave 0, now:** T-TS-01, T-TS-02. Docs only, no dependency.
- **Wave 1, inside GL, after CM confirms and GL's 24 October work lands:** T-TS-03 (the port), T-TS-04 (contract fixtures, GL as provider), T-TS-05 (change log and roles). Nothing moves yet; consumers can already read the contract.
- **Wave 2, the repo (parallel with Wave 1):** T-TS-06 (CM), T-TS-07 (scaffold).
- **Wave 3, the service:** T-TS-08, T-TS-09, T-TS-10, T-TS-17, T-TS-24 and T-TS-25 (the catalogue), then T-TS-11 (seed and compare).
- **Wave 4, GL and consumers:** T-TS-12 (read-through copy), T-TS-13 (ledger read), T-TS-15, T-TS-14, T-TS-16.
- **Wave 5, cutover:** T-TS-20 steps 2 to 6.
- **Wave 6, the window:** T-TS-18, T-TS-19 start as soon as T-TS-10 serves the contract, in parallel with Waves 4 and 5.
- **Wave 7, cleanup:** T-TS-21, T-TS-23.

**What is on the critical path:** the port (T-TS-03) and the read-through copy (T-TS-12) are the structural blockers, because they decide whether posting survives a Tax outage. Everything else is straightforward porting.

**Dependencies on other sessions.** GL (port, copy, ledger read, cleanup), CM (repo, infrastructure, cutover, confirmation before any code), Payroll (PAYE consumption), WEB through FiSH+ER WEB (screens), Omniview via CM (operator screens), EA (notices, membership grants), SOP, POP, CBB and IM (reads through the contract). Claim a row in `docs/GL_POP_IM_SOP_Coordination.md` before starting any of them.

## 7. The window: Tax screen requirements for WEB

Direction: Femi, 2026-10-22: "He should provide a window into that portal." This section is the requirement set handed to the FiSH+ER WEB session, which builds all shared front-end work. It describes what the user sees and does, not how it is built. Include the layout-principles checklist (Decisions Log 2026-10-10, section 7) in the handoff; phone-first, compact controls; no hard-coded currency or tax word anywhere (S4, PR-VT-8).

### 7.1 Who and where
- **Users:** Business Owner (read everything), Accountant (read and run computations), and read-only staff with the Tax module grant (`ManagedModule.TAX`).
- **Where:** a Tax area in the shared app, behind the existing module access check. For a Company whose jurisdiction is Planned or Partial, the screens show a plain "not yet available" for the missing parts.
- **Data:** all reads come from the Tax contract (section 3.3), keyed by the Company's jurisdiction code from the Company read.

### 7.2 Screens

| ID | Screen | What the user sees | Source |
|---|---|---|---|
| W-TX-1 | **My jurisdiction** | Country name, the local tax word (VAT, GST, TVA), the Company's currency, and what is available now: VAT, corporate tax, payroll tax, each Full, Partial (with what is missing in plain words) or not yet available; a link to W-TX-9. | `GET /api/jurisdictions` and the Company read |
| W-TX-2 | **VAT categories and rates** | Each category with its rate and effective-from date; the next enacted change with its date as a banner ("From 1 July 2026 this rate becomes 9%"); a date picker to see the schedule as at any date. | `vat-categories?asOf=` |
| W-TX-3 | **Rate history** | A timeline of changes: what changed, when it took effect, whether the source is primary or secondary, and what it superseded. No operator names. | `rate-history` |
| W-TX-4 | **Payroll tax (PAYE) tables** | The bands, thresholds and contribution rates for the jurisdiction as at a date, in the jurisdiction's currency, with an "unverified" mark where a row is not yet verified; read-only. | `payroll-tax?asOf=` |
| W-TX-5 | **VAT return** (Accountant) | Pick a filing period; run or view the return: output VAT, input VAT, net due and direction (payable or refundable), with a breakdown by category and a link to the postings. A return cannot be run if the jurisdiction's VAT is not Full. | `POST` and `GET vat-return` |
| W-TX-6 | **Corporate tax** (Accountant) | Pick a period; see the computation: taxable profit, rule applied, tax due; for a period straddling a rate change, the split or "manual determination" message. | `POST` and `GET tax` |
| W-TX-7 | **Notices** | A banner on any screen that shows an affected rate or category when a change is scheduled; reminder 7 days before; shown on the day (PR-GV-6). Notices come from EA; this screen is where the banner links. | EA notice; `pending` in W-TX-2 |
| W-TX-9 | **Taxes that apply to me** | The catalogue for the Company's jurisdiction: every tax type (VAT, PAYE, social contributions, self-employed taxes, corporate tax, withholding, others) with the local name, who pays, the authority and where to file, how often and by when, the headline rates and thresholds with effective dates, and a status mark (verified, unverified, volatile). Tapping a row opens its detail (the VAT rates, the PAYE tables or the corporate rule) or, for information-only entries, a plain description. A self-employed owner sees the self-employed taxes first. | `tax-types?asOf=` |
| W-TX-10 | **Tax-year selector** | A selector on W-TX-2, W-TX-4, W-TX-5 and W-TX-9 for the tax year (default: the current one), showing the year's start and end and labelling it as the personal tax year, the corporate filing year or the Company's own accounting year where they differ; a mid-year change appears inside the year as a dated step; a year with unsourced figures is marked partial. | `tax-years`, `tax-years/{year}/tax-types` |
| W-TX-11 | **Rules I rely on** (Business Owner, section 3.11) | The list of rules that apply to the Organisation with status chip, change flag, old and new figures, a link to the authority, **Confirm this applies to us**, **Report a problem**, and the Organisation's confirmation history; a summary "N to review, M changed since you last confirmed". | `tax-types`, `tax-years/{year}/tax-types`, `tax-confirmations` |
| W-TX-8 | **Tax and currency help** | A short plain explanation of the tax word, the tax point, and why a rate may differ from another system. | static text from the rulebook |

### 7.3 Behaviour rules
- A rate shown to the owner is a **verified** row only. Unverified rows are shown on W-TX-4 only, marked.
- Every empty or unavailable state is a plain sentence, never a default value.
- Nothing on these screens changes the rulebook. Business Owners and accountants never edit rates.
- Each screen's states are specified before the build: loading, empty, error, partly available.

### 7.4 What is NOT the window
**Operator rulebook screens** (enter a draft row, verify, supersede, mark a review, the impact report) are platform-operator tooling and belong to **Omniview**, which is outside the front-end convention (Decisions Log 2026-10-03); they are specified as T-TS-19 and routed through CM, not WEB.

### 7.5 WEB's review answered (FiSH+ER WEB reviewer, 2026-10-22)

**Layers and MVP order (answers WEB question 1).** Agreed: one Tax area, two layers, so a phone-first Business Owner sees five surfaces, not eleven. **Owner layer:** W-TX-1 My jurisdiction, W-TX-9 Taxes that apply to me, W-TX-7 the notices banner, W-TX-11 Rules I rely on, W-TX-8 help. **Accountant layer** (a second tab behind one tap): W-TX-2 VAT categories and rates, W-TX-3 rate history, W-TX-4 PAYE tables, W-TX-5 VAT return, W-TX-6 corporate tax; W-TX-10 the tax-year selector is a control on W-TX-2, 4, 5 and 9, not a screen. The layer is a layout choice, not a role: WEB shows both tabs to anyone with the Tax grant and the server answers 403 where it must (answer 5).

| Order | Screens | Why this order (foundations first) | Needs |
|---|---|---|---|
| MVP 1 | W-TX-1, W-TX-9, W-TX-8 | Femi asked first for the tax context of each country; these are read-only reference data and the easiest to ship | `jurisdictions`, `tax-types` |
| MVP 2 | W-TX-2, W-TX-10 | VAT rates already exist in GL's `vat-categories`; the year selector needs the by-year reads | `vat-categories`, `tax-years` |
| MVP 3 | W-TX-11, W-TX-7 | The owner's confirmation and the change banner; needs the confirmation routes and EA notices | `tax-confirmations`, EA notice |
| MVP 4 | W-TX-4, W-TX-3 | PAYE tables and history | `payroll-tax`, `rate-history` |
| MVP 5 | W-TX-5, W-TX-6 | Computations; depend on GL's VAT-line read (T-TS-13) and the Tax computation routes (T-TS-14) | the return and tax computation reads and writes |

**Contract additions (answers WEB question 2).** Starting points are GL's existing fixtures `vat-return.json` and `tax-computation.json`; each addition is published as a fixture first and declared by WEB before Tax sends it (answer 3). Refusal codes keep GL's existing stable codes; the new ones below are declared with their fixtures.

| Route | Shape |
|---|---|
| `GET /api/companies/{companyId}/vat-returns?from=&to=` | A list of past returns, newest first: `{"returns":[{id, filingPeriodStartDate, filingPeriodEndDate, outputVat, inputVat, netVatDue, direction, currency, computedAt}]}`, the entry shape of `vat-return.json`. |
| `GET /api/companies/{companyId}/vat-returns/{id}` | One return: `vat-return.json` plus an additive `categoryBreakdown` (category, base and VAT, derived from the tagged lines, not stored). |
| `POST /api/companies/{companyId}/vat-returns` | Computes and stores a return for `{filingPeriodStartDate, filingPeriodEndDate}`; `Idempotency-Key` required; the same key replays the same result. GL's `POST /companies/{companyId}/vat-return` keeps working as the interim path. |
| `GET /api/companies/{companyId}/tax-computations` and `.../tax-computations/{id}` | Corporate tax: the list by period and one by id, the entry shape of `tax-computation.json`. `POST` takes `{periodId}` or a date range, with `Idempotency-Key`; for a straddling period the response carries `splitPeriods` or the refusal `straddle_manual_determination` (PR-CT-1). |
| `GET /api/companies/{companyId}/tax-confirmations` | `{"companyId":..., "confirmations":[{"rowKey":"VAT/STANDARD","rowVersion":17,"confirmedBy":"owner@example.com","confirmedAt":"2026-10-22T09:00:00Z","note":null}]}`. |
| `POST /api/companies/{companyId}/tax-confirmations` | Body `{rowKey, rowVersion, note?}`; `Idempotency-Key` required; 201 on first write, 200 with the original on replay. Refusals: 409 `row_version_superseded` (the row changed since the screen loaded; the body names the current `rowVersion`), 404 `row_not_found`, 400 `bad_request`, 403 `forbidden`. |
| `POST /api/companies/{companyId}/tax-problem-reports` | Body `{rowKey, rowVersion, message}` (message up to 2,000 characters); `Idempotency-Key` required; 201 `{id, status:"OPEN"}`. Same refusals. The report goes to the verifier's queue (3.10) with who reported it. |
| `payroll-tax` | Every section carries a per-row `status` (`VERIFIED`, `UNVERIFIED`, `CONFLICT`): `incomeTax.status` and each `contributions[].status`, plus an optional `statusNote` in plain words. Bands inherit their section's status. |
| `tax-types`, `tax-years/{year}/tax-types` | Each entry already carries `status` and `volatile`; additive `verifiedOn` (date) and `source` (`PRIMARY` or `SECONDARY`) are added for the "Rules I rely on" screen. |

**Link to the postings (W-TX-5).** Tax does not return a link. WEB composes it: GL's VAT-line read `GET /companies/{companyId}/vat-lines?from=&to=` (GL-T-32), called with the return's filing period. **Notices (W-TX-7).** The notice shape is EA's. Tax hands EA `{kind:"TAX_CHANGE", jurisdiction, rowKey, rowVersion, effectiveFrom, summary}`; Tx will agree the field names with EA before T-TS-33 and WEB reads the notice from EA's existing route, not from Tax.

**Fixtures first (answer 3).** Accepted as stated: every read gets a golden fixture in `fish-contracts` before the route ships: a success, the empty or not-configured case, partial availability, and each refusal. Every added field and every new enum value (tax-type codes, availability states, statuses, `family`, `payer`) is published as a fixture and declared by WEB before Tax sends it; WEB shows a generic sentence for a value it does not know. Tx will tell CM before touching `fish-contracts`.

**Money and words (answer 4).** Agreed. Amounts in W-TX-5 and W-TX-6 arrive as decimal strings at the currency's minor units (GNF and XOF have none), with the currency code in the body; rates arrive as decimal percent strings. The tax word comes from `taxWord` and the currency from the Company read; no literal in Tax's responses or WEB's screens. Existing WEB labels that say "VAT" move to `taxWord` in a later label branch, not in T15.

**Access (answer 5).** Agreed: WEB uses the existing module-grant check only and does not invent an Accountant rule; the server decides and answers 403, which WEB shows as a plain line. `ManagedModule.TAX` exists in GL's tenancy (migration V16, membership grants); **whether EA's `GET /me` already emits it in `grantedModules` is not verified by Tx**; WEB declares it consumer-first and EA confirms.

**Provider switch (answer 6).** One per-service base URL (`VITE_TAX_API_BASE_URL`, fail-closed in strict mode) is right; the move from GL to Tax is a configuration change because the contract is identical. CORS: Tax's scaffold allows `Authorization` and `Content-Type` and `GET`; before the first write route Tax adds `POST`, `Idempotency-Key` and `X-Tenant-Id`, and allows WEB's origin through `TAX_CORS_ALLOWED_ORIGIN`. Tell Tx if WEB sends any other header.

**Caching (answer 7).** Use `rulebookVersion` as the cache key. Expected freshness: rulebook data changes rarely; WEB probes `GET /api/rulebook-version` when a Tax screen opens and at most every 5 minutes while it stays open, and treats a copy older than one hour as stale (re-fetch). A version change invalidates every cached Tax read.

**States (answer 8).** For every screen WEB specifies, and Tx confirms, these states before the build: loading; empty because the jurisdiction is Planned ("not yet available"); partial (some tax types available, some not); unverified rows; a flagged row; a value the screen does not know (generic sentence); an error; and a 403 (plain line). W-TX-11 adds: nothing to review; changes to review; and the confirm and report actions in flight, failed and replayed. Tx will review WEB's front-end half against this list.

## 8. PAYE: what Tax provides, and how Payroll consumes it

### 8.1 What Tax holds for payroll
For each jurisdiction and effective window:
- **Income tax (PAYE or equivalent):** a list of bands (lower bound, upper bound or none, rate), personal allowance or tax-free threshold, and the currency of the figures and whether the band unit is confirmed (`thresholdUnitConfirmed`).
- **Social contributions:** employee and employer rates, caps and floors, and the name the jurisdiction uses (National Insurance, PRSI and USC, NASSIT, NASSCORP, CNSS, CNPS, pension and NSITF where applicable), each with its own band or cap.
- **Status per row:** `verified`, `unverified` or `conflict`, with source class; unverified rows are served marked, and Payroll refuses to compute from them.
- **Currency:** the jurisdiction's own currency; Payroll's existing currency check (pay in the Company's currency) still applies.

### 8.2 The contract read
`GET /api/jurisdictions/{code}/payroll-tax?asOf=` returns `{"jurisdiction":"UK","asOf":"...","rulebookVersion":41,"currency":"GBP","incomeTax":{"allowance":"...","bands":[{"lower":"0","upper":"37700","ratePercent":"20"}, ...],"status":"VERIFIED"},"contributions":[{"name":"National Insurance","party":"EMPLOYEE","ratePercent":"8","lowerThreshold":"...","upperLimit":"...","status":"VERIFIED"}]}` as a first shape, refined with Payroll's own `TaxBand` before the fixture is written. Fields are additive and nullable.

### 8.3 How Payroll consumes it
1. Payroll holds a read-through copy of the payroll-tax window for each Company's jurisdiction, exactly as GL holds VAT (section 3.4), refreshed by the same version probe.
2. Payroll keeps the **computation** (deductions are the owning service's, Decisions Log 2026-10-18) and replaces its unpopulated `PayrollTaxRule` storage with the copy.
3. A pay run reads the copy; if the rule is unverified, missing for the date, or in another currency than the Company's, the pay run is refused with a plain message.
4. The tables are data in Tax, entered by the editor and verified by the verifier like any rule; no number is ever a literal in Payroll's code.

### 8.4 What data exists today (from the country tax docs and YAML)
| Jurisdiction | PAYE data on file | Known status |
|---|---|---|
| UK | Bands and NI figures from HMRC (real, current) | verified source; England, Wales and NI only, Scotland not represented |
| Ireland | Five income tax bands plus USC and PRSI; employer-side PRSI blank | verified source for bands; PRSI employer rate needs a follow-up |
| Nigeria | Personal income tax bands under the Nigeria Tax Act 2025 | secondary sources in part; employer pension flagged under review |
| Sierra Leone | Five bands, 0/15/20/25/30% | **thresholds' currency unit unresolved** (old Leone versus New Leone); `unverified` |
| Liberia | PAYE bands | NASSCORP has two incompatible source versions; `conflict` |
| Guinea | Six brackets 0% to 20% (Article 63, Law L/2021/032/AN) and an employer CNSS rate | best-sourced; statute text read was a draft code |
| Cote d'Ivoire | ITS bands after the 2024 reform; CNPS itemised | volatile in places; flagged |

## 9. Evidence and what was not verified
- **Catalogue data on file today (country docs and YAML, section keys):** UK: corporation tax, VAT, PAYE, National Insurance. Ireland: corporation tax, VAT, income tax, USC, PRSI. Nigeria: companies income tax, VAT, personal income tax, pension. Sierra Leone: corporate income tax, GST, PAYE, NASSIT. Liberia: corporate income tax, GST, PAYE, NASSCORP. Guinea: corporate income tax, TVA, ITS, CNSS. Cote d'Ivoire: corporate income tax, TVA, ITS, CNPS. **No country doc has a self-employed or sole-trader section**, and capital gains, withholding, payroll levies (Sierra Leone Payroll Tax Act, Guinea Versement Forfaitaire, Cote d'Ivoire employer contribution, Nigeria development levy) appear only in research digests. T-TS-24 closes this gap; two researchers were sent out for it on 2026-10-22 and their findings go in a new section of the research digest before anything is seeded.
- The inventory in section 1 is from reading the GL checkout and the `fish-contracts` fixtures on 2026-10-22; the **VAT Control Account line read** Tax needs is not confirmed to exist as a separate GL route (the return use case reads the lines internally today).
- The proposed host name, database name, refresh interval (15 minutes), horizon (400 days) and alarm threshold (one hour) are proposals for CM and GL to confirm.
- The PAYE contract shape in 8.2 is a first shape, not checked against Payroll's `TaxBand` and `PayrollTaxType` beyond reading them.
- Country PAYE figures are from the docs on file (section 8.4) and carry the source and status noted there; they have not been re-verified against primary texts (verification items V-1 to V-13 of the Policy Resolution playbook).
- Whether 24 October VAT deliveries touch any file this plan names is for GL to say; this playbook asks GL to introduce the port in its own time (TS-9).

## 10. Identifier index (for traceability)

IDs are stable: never renumbered or reused; a dropped item keeps its ID; new items are appended. Status: DRAFT until Femi records approval in the Decisions Log.

| Kind | IDs | Where defined |
|---|---|---|
| Decisions | Q1 to Q9 | 3.1 |
| Requirements | TS-1 to TS-16 | 3.2 |
| Principles | S1 to S6 | 2.4 |
| Use cases | UC-TS-1 to UC-TS-15 | 4 |
| Tasks | T-TS-01 to T-TS-34 (expand T-PR-30 to T-PR-32 of the Policy Resolution playbook) | 5 |
| Window screens | W-TX-1 to W-TX-11 | 7.2 |
