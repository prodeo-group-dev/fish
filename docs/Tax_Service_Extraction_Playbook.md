# Tax Service (fish-tax) Extraction Playbook

**Status: DRAFT, 2026-10-22. Docs and design only; no code, no contract fixtures and no GL change until CM confirms.** Nothing here is approved until Femi records approval in `docs/Decisions_Log.md`.

**Owner:** Tax Jurisdiction session (Tx). **Related:** `docs/Tax_Extraction_DDD_Design.md` (2026-09-19, the original design; its section 8 questions are answered here), `docs/Tax_And_Currency_Policy_Resolution_Playbook.md` (section 11 and PR-TX-1 to PR-TX-4), `docs/Tax_And_Currency_Jurisdictions_Playbook.md`, `docs/Tax_And_Currency_Policy_Resolution_Research_Digest.md`.

**Decisions this playbook rests on (all Femi, 2026-10-22, logged):**
1. "All things Tax should be abstracted to Tx."
2. Extract now: "No time like the present. Let us extract things that need to do with taxes to Tx. It will provide context for PAYE, and VAT." This overrules the earlier "after the Live switch and UAT" timing. It runs in parallel with, and does not delay, the 24 October VAT deliveries in GL.
3. "He should provide a window into that portal." Tx provides a Tax screen in the shared front end.
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
| TS-10 | **Operations.** Tax emits JSON logs with a `requestId`, has a real `/health`, per-service database, rate limiting on writes, backup and restore documented, and graceful shutdown, matching the platform readiness findings. | Tx, CM | S | T-TS-07, T-TS-06 |

### 3.3 The read contract (T-PR-30), specified

Paths are under Tax's `/api`. All reads require a valid service-account token or a human token with the Tax module grant. Responses are strict JSON; fields are only ever added, as nullable. `rulebookVersion` increases whenever any approved row changes.

| Read | Purpose | Shape |
|---|---|---|
| `GET /api/jurisdictions` | The registry for company creation and the Tax screen | `{"rulebookVersion": 41, "jurisdictions": [{"code":"UK","name":"United Kingdom (including Northern Ireland)","currency":"GBP","currencyStatus":"ONBOARDED","taxWord":"VAT","availability":{"companyCreation":"FULL","vat":"FULL","corporateTax":"FULL","payrollTax":"PARTIAL"}}]}`. Today's `GET /jurisdictions` is the first three fields; `currencyStatus`, `taxWord` and `availability` are added. |
| `GET /api/jurisdictions/{code}/vat-categories?asOf=YYYY-MM-DD` | VAT categories and rates at a date | `{"jurisdiction":"UK","asOf":"2026-10-12","rulebookVersion":41,"vatScheduleConfigured":true,"categories":[{"category":"STANDARD","ratePercent":"20","effectiveFrom":"2011-01-04","pending":null},{"category":"REDUCED","ratePercent":"5","effectiveFrom":"1992-04-01","pending":null},{"category":"ZERO_RATED","ratePercent":"0","effectiveFrom":"1973-04-01","pending":null},{"category":"EXEMPT","ratePercent":null,"effectiveFrom":"1973-04-01","pending":null}]}`. Today's GL route returns the first four fields and `categories` with `category` and `ratePercent`; `effectiveFrom` and `pending` (the next enacted change, `{"effectiveFrom","ratePercent"}`) are added, and `rulebookVersion`. Only **verified** rows appear (PR-GV-4). The refusal when nothing is configured keeps today's shape (`vatScheduleConfigured: false`, empty categories). |
| `GET /api/jurisdictions/{code}/vat-categories/window?from=&to=` | A rate window for a read-through copy | the same category rows with every effective window overlapping the range, plus pending rows up to the horizon |
| `GET /api/jurisdictions/{code}/rules?asOf=` | The corporate rule matrix by tax type | `{"jurisdiction":"IE","asOf":"...","rulebookVersion":41,"rules":[{"taxType":"CORPORATE_INCOME_TAX","rateStructure":{...},"effectiveFrom":"...","sourceClass":"PRIMARY"}]}` (shape as `rate_structure` encodes today, exposed as JSON) |
| `GET /api/jurisdictions/{code}/payroll-tax?asOf=` | PAYE bands and contribution rates | section 8.2 |
| `GET /api/jurisdictions/{code}/rate-history?type=&from=&to=` | The rulebook change history for the window screen | rows of `{"changedOn","summary","effectiveFrom","sourceClass","supersedes"}`; no operator names (Prodeo is a landlord; role-level only) |
| `GET /api/rulebook-version` | Cheap version probe for cache refresh | `{"rulebookVersion": 41}` |

Computation routes (Tax calls GL): `POST /api/companies/{companyId}/tax` (corporate tax for a period or date range) and `POST /api/companies/{companyId}/vat-return` (VAT return for a filing period), keeping today's request and response shapes, with the audit record stored in Tax.

Operator writes (Omniview): create a draft row, verify, supersede, mark a review. Never exposed to a Tenant.

Refusal codes keep today's stable codes: `no_vat_rate_schedule`, `no_tax_rule`, `vat_category_not_supported`, `company_not_found`; new: `rulebook_unavailable` for a caller that asked for a rate window the copy cannot serve.

### 3.4 The local read-through copy (T-PR-31), designed

**The problem.** Posting a sale needs the VAT rate now. If GL called Tax for each posting, a Tax outage, deploy or slow response would stop every sale and purchase in the platform (S1, TJ-NFR-7).

**The design.**
1. **A narrow port.** GL introduces one rate-lookup port, `RateSource` (T-TS-03): `rateFor(jurisdiction, category, taxPointDate)`. The three posting use cases call only this port. Before extraction it is backed by GL's own `vat_rates` table. After extraction it is backed by the local copy. No posting code changes at cutover.
2. **A local copy, not a cache of responses.** GL keeps a table `tax_rate_copy(jurisdiction, category, rate_percent, effective_from, effective_to, pending, rulebook_version, fetched_at)`. In fact it is today's `vat_rates` table, kept as a read model that Tax now populates; GL stops writing it.
3. **Refresh, not request-time fetch.** A refresher in GL pulls `GET /api/rulebook-version`; if it changed it pulls `vat-categories/window` for each enabled jurisdiction and replaces the rows in one transaction. It runs on start, every 15 minutes, and on an optional manual trigger. The window it fetches runs from the earliest effective date any open document can have to **400 days ahead**, so a pending change is present before its effective day.
4. **Posting reads only the local copy.** If the copy has no row for the date, posting refuses with the existing `no_vat_rate_schedule` error (never a default, per the Decisions Log 2026-10-15), and logs that the copy may be stale.
5. **Tax down is fine.** The copy keeps serving. Rates are effective-dated facts; a rate in force on a date changes only by a correction, which the refresher picks up after Tax recovers.
6. **Staleness is visible, not blocking.** `fetched_at` and `rulebook_version` are on a GL admin read and in a metric; an alarm fires if `fetched_at` is older than one hour. Posting does not block on staleness.
7. **Corrections.** A correction row in Tax is a new effective-dated row. Each posted VAT line records the **rate row it used** (rate, effective-from and rulebook version), so the impact query (PR-GV-8) can list postings made under a superseded row.
8. **First deploy.** The table already holds the live rows; the first Tax export is compared with it row by row (T-TS-11) before GL switches its refresher on.

**Failure modes.**

| Event | Result |
|---|---|
| Tax unreachable for hours | Posting continues from the copy; alarm after one hour stale. |
| Tax returns an unexpected shape | The refresher keeps the old copy, logs the error, alarms; strict decoding makes the break loud (S3). |
| A rate is corrected in Tax | The next refresh replaces it; earlier postings keep the row they used and appear in the impact report. |
| A jurisdiction is added or becomes available | Appears at the next refresh; a Company created in it before then waits at most the refresh interval. |
| Copy missing a date | `no_vat_rate_schedule`; nothing is posted. |

**Who needs a copy.** GL (posting) in phase one; Payroll (PAYE) in phase two (section 8). SOP, POP, CBB and IM read the rate through GL's facade (`GET /companies/{companyId}/vat-categories`, kept for a release) and so inherit the copy; they move to reading Tax directly only if they need to. WEB reads Tax directly (online, display only).

### 3.5 What moves, what stays

| Moves to `fish-tax` | Stays in GL |
|---|---|
| Tables: `jurisdictions`, `tax_rules`, `tax_computations`, `vat_rates` (becomes Tax's source of truth; GL keeps a copy under TS-4), `vat_returns` | `companies` (with the jurisdiction **code**), `periods`, `journal_entries`, `journal_lines`, the VAT Control Account and all postings |
| `domain/tax/*` (rule, type, rate structure, computation, VAT category, rate schedule, filing period, return, repositories, ids), `ComputeTaxUseCase`, `ComputeVatCategoriesUseCase`, `ComputeVatReturnUseCase`, `TaxRoutes`, `VatCategoriesRoutes`, `VatReturnRoutes`, `JurisdictionRoutes`, the Exposed repositories, `rate_structure_encoding`, tests | The three posting use cases (they call the `RateSource` port), the profit-and-loss report route, the VAT-control-line read (new, TS-5), `ManagedModule.TAX` (tenancy), the VAT calculator input (the document owner's job) |
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
| 6 | Computation routes move; Tax calls GL's read routes. GL keeps a facade that answers 410 with a pointer for one release. | route back | return reproduced for a known period |
| 7 | After an agreed period, GL removes the moved code and tables (T-TS-21), with CM. | none (restore from backup) | Femi's go |

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
| T-TS-12 | GL read-through copy and refresher, alarm, admin read (T-PR-31 build) | GL | 5 | T-TS-03, T-TS-10 |
| T-TS-13 | GL: VAT Control Account lines by direction for a date range (read for Tax); P&L `?from&to` already exists | GL | 2 | CM confirm |
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

## 6. Order (O): foundations before features

- **Wave 0, now:** T-TS-01, T-TS-02. Docs only, no dependency.
- **Wave 1, inside GL, after CM confirms and GL's 24 October work lands:** T-TS-03 (the port), T-TS-04 (contract fixtures, GL as provider), T-TS-05 (change log and roles). Nothing moves yet; consumers can already read the contract.
- **Wave 2, the repo (parallel with Wave 1):** T-TS-06 (CM), T-TS-07 (scaffold).
- **Wave 3, the service:** T-TS-08, T-TS-09, T-TS-10, T-TS-17, then T-TS-11 (seed and compare).
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
| W-TX-1 | **My jurisdiction** | Country name, the local tax word (VAT, GST, TVA), the Company's currency, and what is available now: VAT, corporate tax, payroll tax, each Full, Partial (with what is missing in plain words) or not yet available. | `GET /api/jurisdictions` and the Company read |
| W-TX-2 | **VAT categories and rates** | Each category with its rate and effective-from date; the next enacted change with its date as a banner ("From 1 July 2026 this rate becomes 9%"); a date picker to see the schedule as at any date. | `vat-categories?asOf=` |
| W-TX-3 | **Rate history** | A timeline of changes: what changed, when it took effect, whether the source is primary or secondary, and what it superseded. No operator names. | `rate-history` |
| W-TX-4 | **Payroll tax (PAYE) tables** | The bands, thresholds and contribution rates for the jurisdiction as at a date, in the jurisdiction's currency, with an "unverified" mark where a row is not yet verified; read-only. | `payroll-tax?asOf=` |
| W-TX-5 | **VAT return** (Accountant) | Pick a filing period; run or view the return: output VAT, input VAT, net due and direction (payable or refundable), with a breakdown by category and a link to the postings. A return cannot be run if the jurisdiction's VAT is not Full. | `POST` and `GET vat-return` |
| W-TX-6 | **Corporate tax** (Accountant) | Pick a period; see the computation: taxable profit, rule applied, tax due; for a period straddling a rate change, the split or "manual determination" message. | `POST` and `GET tax` |
| W-TX-7 | **Notices** | A banner on any screen that shows an affected rate or category when a change is scheduled; reminder 7 days before; shown on the day (PR-GV-6). Notices come from EA; this screen is where the banner links. | EA notice; `pending` in W-TX-2 |
| W-TX-8 | **Tax and currency help** | A short plain explanation of the tax word, the tax point, and why a rate may differ from another system. | static text from the rulebook |

### 7.3 Behaviour rules
- A rate shown to the owner is a **verified** row only. Unverified rows are shown on W-TX-4 only, marked.
- Every empty or unavailable state is a plain sentence, never a default value.
- Nothing on these screens changes the rulebook. Business Owners and accountants never edit rates.
- Each screen's states are specified before the build: loading, empty, error, partly available.

### 7.4 What is NOT the window
**Operator rulebook screens** (enter a draft row, verify, supersede, mark a review, the impact report) are platform-operator tooling and belong to **Omniview**, which is outside the front-end convention (Decisions Log 2026-10-03); they are specified as T-TS-19 and routed through CM, not WEB.

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
| Requirements | TS-1 to TS-10 | 3.2 |
| Principles | S1 to S6 | 2.4 |
| Use cases | UC-TS-1 to UC-TS-10 | 4 |
| Tasks | T-TS-01 to T-TS-23 (expand T-PR-30 to T-PR-32 of the Policy Resolution playbook) | 5 |
| Window screens | W-TX-1 to W-TX-8 | 7.2 |
