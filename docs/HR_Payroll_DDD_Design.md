# FiSH HR/Payroll System — Domain-Driven Design (design-only, no code yet)

**Status: design scoping, 2026-08-20. Nothing built.** This is the sibling system confirmed necessary in `docs/DDD_Design.md` Section 2.7 ("HR/Payroll is a separate system, not a package of the GL Engine") and reaffirmed in Section 10.17 — the GL Engine's posting interface (`PayRun`, `LeaveAccrual`) has been sitting complete with no caller since 2026-08-24. This document scopes the system that will be that caller. It lives at the `FiSH/` top level, not under `docs/UK/`, because HR/Payroll is cross-venture — Purse (all four jurisdictions), Scrip, Osusu, BuzzMe, and any B2B tenant all need it, the same reason `docs/DDD_Design.md` itself isn't jurisdiction-scoped.

**Amended 2026-09-01 — `PostPayRunUseCase` retired from GL, every reference below to it is now historical.** `fish-hr-payroll`'s own `KtorGlEngineGateway` (built since this document was written) confirmed it only ever calls `POST /payroll/record-pay-run` (`RecordPayRunUseCase`) — `PostPayRunUseCase`'s persisted-lookup-by-ID flow (`POST /pay-runs/{payRunId}/post`) had no caller anywhere, the same dead end `PostPurchaseOrderUseCase`/`PostSalesOrderUseCase`/`PostInventoryReceiptUseCase`/`PostInventoryIssueUseCase` all turned out to be (`docs/DDD_Design.md`'s own StockItem-retirement note). GL deleted `PostPayRunUseCase`, `PayRunRepository`, and the dead route the same day. Every mention of `PostPayRunUseCase` in this document (§0/§3.4/§7.2/§7.4) describes what was true when written, kept for context rather than rewritten — read it as `RecordPayRunUseCase` going forward. `PayRun.create()`/`PayRun.post()` themselves are unchanged; only the persisted, found-by-ID posting path around them is gone.

**Both provisional defaults resolved 2026-08-20, same day — re-asked after the user flagged the first pass had gone unanswered.** (a) **Both halves are in scope for this design pass** — Staff Cost Analysis, Performance Review, and Staff Development together, not deferred. See §5/§6, no longer stubs. (b) **`PayrollTaxRule`'s bracket shape stays jurisdiction-agnostic**, but is populated with UK PAYE/NI and Irish PAYE/PRSI/USC bands first — matching the entities actually named in `HR/docs/HR_Payroll_Requirements_Use_Cases.md` (Scrip/Purse/Prodeo Capital/Prodeo Property SPV), not Sierra Leone. See §3.3.

---

## 0. Relationship to the GL Engine repo

This is **not** a package inside `fish-fish-gl-engine`, the same relationship Lending has (`docs/DDD_Design.md` Section 2.3). It's a separate codebase that **posts staff-cost financial effects into FiSH** by calling three already-built, already-tested application-layer use cases:

| GL Engine use case | Called when | Reference |
|---|---|---|
| `PostPayRunUseCase` | Each pay run, with company-level `totalWages`/`totalSalaries` totals | `docs/DDD_Design.md` §10.17 |
| `RemeasureLeaveAccrualUseCase` | Whenever an employee's accrued-leave entitlement changes (period-end accrual) | `docs/DDD_Design.md` §10.18 (`project_leave_accrual_use_cases`) |
| `UtilizeLeaveAccrualUseCase` | When an employee takes accrued leave and is paid for it | same |

**Integration mechanism confirmed 2026-08-20: HR/Payroll must call the GL Engine's HTTP API — not a direct/in-process code call, not a shared database, not an event/message queue.** Given HR/Payroll is a genuinely separate codebase, this was always implied, but the user made it explicit as a hard requirement rather than leaving it inferred. **Verified against the actual built GL Engine (`GL/src/main/kotlin/com/theprodeogroup/fish/infrastructure/web/`) — all three routes already exist, nothing to build on the GL Engine side:**

| Use case | HTTP route |
|---|---|
| `PostPayRunUseCase` | `POST /pay-runs/{payRunId}/post` |
| `RemeasureLeaveAccrualUseCase` | `POST /leave-accruals/{leaveAccrualId}/remeasure` |
| `UtilizeLeaveAccrualUseCase` | `POST /leave-accruals/{leaveAccrualId}/utilize` |

**The contract HR/Payroll must satisfy as an API caller, per `Auth.kt`'s actual implementation:**
- **Bearer JWT**, verified via an external IdP's JWKS (RS256) — the GL Engine issues no tokens itself, it only verifies them. HR/Payroll needs its own path to obtaining a valid token from whatever IdP FiSH trusts (a service-account/machine-to-machine credential, most likely — not designed here, a real open item, see §7).
- Caller identity resolves via the JWT's `email` claim → a `User` with at least one `ACTIVE` `Membership`, else 401. HR/Payroll's calling identity needs a real `User`/`Membership` record in FiSH's own Tenancy context, the same as any human caller — it doesn't get a special machine-caller bypass.
- **`X-Tenant-Id` header required on every request**, verified against the actual owning Tenant of the targeted resource (`PayRun`/`LeaveAccrual`'s Company → Tenant), 403 on mismatch. HR/Payroll must know which FiSH Tenant a given Company belongs to before calling — this is `Employee.companyId` (§3.1) plus whatever Tenant-resolution HR/Payroll does on its own side.
- Write access additionally requires a **non-`READ_ONLY` Membership role** in that Tenant.

**The contract these three use cases impose on this system, non-negotiable without a GL Engine change:**
- `PayRun.create()` takes company-level `totalWages: Money` + `totalSalaries: Money` only — **no `Employee` reference crosses into the GL Engine at all.** Whatever this system does internally with per-employee gross pay, deductions, and employer costs, it must collapse to two totals before calling `PostPayRunUseCase`.
- `LeaveAccrual` is `EmployeeId`-scoped (the one place an employee identity *does* cross the boundary, because the liability is inherently per-employee) but carries no other operational detail — just a `Money` target/utilization amount.
- **The double-counting risk flagged in `docs/DDD_Design.md` §2.7 is this system's responsibility to close, not the GL Engine's — resolved 2026-08-20, see §3.4/§4 for the full shape.** When an employee takes accrued leave, splitting that pay period's money into "worked" (goes into `PayRun.totalWages`/`totalSalaries`) vs. "leave-funded" (goes into `LeaveAccrual.utilizeLeave()` instead) happens here, per employee, at every pay run.

Everything else this document scopes — `Employee`, salary advances, tax/NI computation, performance review, staff development — has **zero visibility to the GL Engine.** It's internal to this system, referenced only via `EmployeeId` when calling the two `LeaveAccrual` use cases.

---

## 1. Ubiquitous Language

| Term | Meaning |
|---|---|
| **Employee** | A person employed by a Company (one of the four FiSH ventures, or a B2B tenant's own company), with employment terms, salary rate, and bank details. Never referenced by the GL Engine except as an opaque `EmployeeId` on `LeaveAccrual`. |
| **Pay Run** | A batch calculation across some or all of a Company's Employees for a pay period, producing per-employee net pay plus the two GL-facing totals (`totalWages`, `totalSalaries`) this system hands to `PostPayRunUseCase`. |
| **Deduction** | An amount withheld from an Employee's gross pay (tax, NI/social security, pension, salary-advance recovery, etc.) before net pay is calculated. Generic and named, not hard-coded per jurisdiction — same "data, not code" treatment `TaxRule` already uses in the GL Engine. |
| **Employer Cost** | An amount the employer incurs *in addition to* gross pay (employer NI/social security contribution, employer pension contribution) — doesn't reduce the employee's net pay, but does add to the Company's total staff cost. |
| **Salary Advance** | Employer advances an Employee money ahead of normal pay, recovered via a Deduction line over one or more subsequent Pay Runs. Confirmed in `docs/DDD_Design.md` §2.7 as structurally simpler than Lending — no APR ceiling, no arrears staging, no common-bond eligibility. |
| **Payroll Tax Rule** | Jurisdiction-specific tax/NI computation configuration — this system's equivalent of the GL Engine's `TaxRule`, but payroll tax is virtually always progressive-bracket, not flat-rate, so the shape must support brackets, not just a single `rate: BigDecimal`. |
| **Appraisal** (confirmed 2026-08-20) | The 360° gathering-and-aggregation process — self-assessment, line-manager assessment, anonymised peer feedback, anonymised upward feedback — that produces the inputs to a `PerformanceReview`. A **component of** `PerformanceReview`, not a separate module and not identical to it. |
| **Performance Review** | The record of an Employee's assessment for a period: the per-direction ratings an Appraisal gathers, plus the human-determined overall outcome from the review discussion. All ratings use a fixed 1–5 Likert scale. No financial effect. Its outcome **feeds** Staff Development (a training request) only — **not compensation review**, decided against 2026-08-20 (§5). |
| **Staff Development** | Training/qualification management — receives training requests from Performance Review outcomes. No financial effect, no GL Engine interaction. |
| **Training Record** | An Employee's completion of a course/qualification — provider, completion date, and (where relevant, e.g. compliance-mandated training) an expiry/renewal date. No financial effect. |

---

## 2. Bounded Context

**One bounded context, three cleanly separable subdomains** — revised 2026-08-20 from the original two-subdomain split (`docs/DDD_Design.md` §2.7's "analyses staff costs and manages staff development" only named two, but the 360° appraisal requirements doc made clear Performance Review is structurally its own thing, not a Staff Development aggregate):

- **Staff Cost Analysis** (§3/§4) — Employee master data, Pay Run batching/calculation, Salary Advances, Payroll Tax Rules. Financial-effect-producing; the only subdomain that ever calls into the GL Engine.
- **Performance Review** (§5) — the Appraisal gathering-and-aggregation process plus its documented outcome. No financial effect, no GL Engine interaction. **Upstream of** Staff Development, not contained by it: its outcome feeds Staff Development (a training request). **Not upstream of Staff Cost Analysis** — UC-SA9's compensation-review linkage was decided against 2026-08-20 (§5), so there is no touchpoint into `Employee`/salary at all.
- **Staff Development** (§6) — training/qualification records. No financial effect, no GL Engine interaction. Downstream of Performance Review.

**Confirmed 2026-08-20, precise relationship language:** "Appraisal is a subset of Performance Review" (component-of) and "Performance Review feeds Staff Development" (upstream-of) — not "Appraisal feeds Staff Development" directly. Performance Review is the thing that crosses subdomain boundaries; Appraisal never does, it's internal to Performance Review.

Whether these three end up as separate bounded contexts sharing one repo/deployment, or genuinely separate systems, is still open (§7). They share very little data — `EmployeeId` and nothing else; Staff Cost Analysis and Performance Review have zero touchpoints now that compensation linkage is decided against.

**Build/implementation priority confirmed 2026-08-20: Staff Cost Analysis first.** All three subdomains got a design pass together (§0), but when this moves from design to actual scaffolding, Staff Cost Analysis (§3/§4 — `Employee`, `PayrollTaxRule`, the batching aggregate, leave tracking, and the calls into `PostPayRunUseCase`/`RemeasureLeaveAccrualUseCase`/`UtilizeLeaveAccrualUseCase`) comes before Performance Review (§5) and Staff Development (§6). Consistent with why Staff Cost Analysis is the only subdomain grounded in a real requirements doc (`HR/docs/HR_Payroll_Requirements_Use_Cases.md`) and the only one with a genuine dependency on already-built GL Engine code — the other two have no such external pressure forcing them first.

---

## 3. Aggregates (Staff Cost Analysis subdomain)

### 3.1 `Employee` — **built 2026-08-21**, `HR/src/main/kotlin/com/theprodeogroup/hr/domain/staffcost/employee.kt`, 27 tests (13 `Money` + 14 `Employee`)

Master data. Fields (draft, not final):
- `id: EmployeeId` — reuses the GL Engine's own `EmployeeId` value class *by value* (same UUID scheme), not the same Kotlin type, since this is a separate codebase. When calling `LeaveAccrual` use cases, this system passes the raw UUID and the GL Engine wraps it in its own `EmployeeId`.
- `companyId` — which Company (GL Engine's `CompanyId`, same by-value reuse) the Employee belongs to.
- `name`, `bankDetails` (for pay disbursement — this system likely owns actual bank-transfer initiation, or hands off to a payment rail, itself an open integration question).
- `employmentTerms` — salary vs. hourly, contracted hours, start/end date.
- `salaryRate: Money` (or hourly rate) — this system's own Money type, mirroring the GL Engine's amount+currency-together convention (`docs/DDD_Design.md` conventions, `[[feedback_money_design_praised]]`).
- `payFrequency` — weekly/monthly/etc., since a Company may run multiple Pay Runs of different frequencies for different Employee groups.
- `standardWorkingDaysPerYear: Int` — **added 2026-08-20**, needed for §3.4's leave-day-to-money conversion (`salaryRate / standardWorkingDaysPerYear` for salaried Employees). A **fixed, per-Employee figure** (e.g. 260 for a full-time 5-day week, prorated down for part-time contracts), not derived from any specific month's actual working days — a fixed denominator keeps a day of leave worth the same amount regardless of which month it's taken in. Hourly Employees don't need this field at all; their leave-day rate is `hourlyRate × contractedHoursPerDay` directly.

### 3.2 `SalaryAdvance` — **built 2026-08-21**, `HR/src/main/kotlin/com/theprodeogroup/hr/domain/staffcost/salary_advance.kt`, 10 tests

- `employeeId`, `principal: Money`, `recoveryAmountPerPayRun: Money` (fixed amount deducted per Pay Run until repaid, capped at the remaining balance on the final installment).
- Simpler than Lending's `ArrearsCase`: no APR, no arrears staging, no common-bond check.

**Disbursement-posting question resolved 2026-08-21, confirmed directly by the user — not the "indirect, no new posting" framing this section originally guessed at:** *"Every Salary Advancement MUST be posted to the GL. Dr Salary Advances Cr Bank/Cash. Salary Advances is a type of control account. Details of Salary Advances and such will be in the HR module."* This is the AP/AR control-account architecture (`AccountsPayableAging`/`AccountsReceivableAging`), applied a third time: FiSH carries a single "Salary Advances" control account (asset, AR's side convention — advance = debit, recovery = credit), with per-Employee subsidiary detail derived from the Ledger via a new `DimensionType.EMPLOYEE` tag (added to `fish-fish-gl-engine`, PR #36, merged) rather than replicated as a GL Engine aggregate. `SalaryAdvance` itself — recovery schedule, negotiation, any other operational detail — is exactly the detail the user's own words place "in the HR module."

**Two postings follow, both excluded from `PayRun`'s company-level totals** (the same double-counting discipline §3.4 already established for leave-funded pay, since `PayRun.post()`'s plain Debit-Expense/Credit-Cash shape can't also touch a third account within the same entry):
- **Disbursement**: Debit Salary Advances (control account, `EMPLOYEE`-tagged) / Credit Cash.
- **Recovery** (per Pay Run installment): Debit Wages Expense / Credit Salary Advances (`EMPLOYEE`-tagged) — no cash movement, since the cash already moved at disbursement; this is what actually draws the control account back down, which folding recovery into a smaller `PayRun` total alone would never do.

**No new GL Engine use case needed for either posting** — both are plain, balanced two-line entries with caller-supplied accounts, exactly what the already-HTTP-exposed `PostJournalEntryUseCase` (`POST /journal-entries`, confirmed to already accept dimension tags in its request payload) is for.

**Not built in `SalaryAdvance` itself, deliberately:** composing the actual `EMPLOYEE`-tagged journal-entry lines and calling `/journal-entries` — that's an application-layer concern, matching `Employee`'s own precedent of staying pure domain code with no HTTP awareness.

### 3.3 `PayrollTaxRule` — **built 2026-08-21**, `HR/src/main/kotlin/com/theprodeogroup/hr/domain/staffcost/payroll_tax_rule.kt`, 16 tests

Jurisdiction-specific, mirrors `TaxRule`'s "global reference data, not Tenant/Company-scoped" pattern (`docs/DDD_Design.md` §10.11) — a jurisdiction's PAYE/NI bands apply to every Employee working there, regardless of which Company or Tenant employs them.

Unlike `TaxRule.rate: BigDecimal` (flat), payroll tax is almost always **progressive brackets**. Shape confirmed 2026-08-20: jurisdiction-agnostic (bands as data, not code — same "data, not code" treatment `TaxRule` already uses):

```
PayrollTaxRule(jurisdiction: String, taxType: PayrollTaxType, bands: List<TaxBand>)
TaxBand(lowerBound: Money, upperBound: Money?, rate: BigDecimal)
```

`upperBound: Money?` (nullable) for the top, uncapped band — same nullable-for-"no upper limit" pattern as `FixedAsset.usefulLifeYears: Int?` meaning non-depreciable. `PayrollTaxType` (`INCOME_TAX`/`SOCIAL_INSURANCE`/`UNIVERSAL_SOCIAL_CHARGE`) combines with `jurisdiction` to fully qualify a real tax — UK+`INCOME_TAX`=PAYE, UK+`SOCIAL_INSURANCE`=NI, Ireland+`INCOME_TAX`=Irish PAYE, Ireland+`SOCIAL_INSURANCE`=PRSI, Ireland+`UNIVERSAL_SOCIAL_CHARGE`=USC (kept as its own value — no UK equivalent, genuinely different computation rules from PRSI, not folded together).

`PayrollTaxRule.create()` enforces a real correctness gate beyond just the shape: bands must start at zero, be contiguous (no gaps or overlaps between `upperBound`/next `lowerBound`), share one currency, and only the last band may be uncapped. `computeTax()` implements genuine progressive-bracket computation — taxing only the portion of income within each band at that band's rate, not the whole amount at whichever band it falls into (a common miscalculation this deliberately guards against, verified with hand-computed multi-band and boundary test cases).

**Still deliberately not populated with real figures anywhere, including in this repo's own tests — held even at actual build time, not just during design scoping.** UK PAYE personal allowance/basic/higher/additional-rate bands and NI thresholds, and Ireland's PAYE/PRSI/USC bands, are statutory figures that change with each tax year (the requirements doc's own cross-cutting requirement 1 flags this as an ongoing compliance liability). Fabricating specific rate/threshold numbers would be worse than leaving them open — every band in `PayrollTaxRuleTest` is explicitly illustrative, not a real HMRC/Revenue.ie figure. Real data population is a separate step sourced from HMRC and Revenue.ie (or a licensed payroll tax service, per UC-HR3's own build-vs-buy question, §8.5), not undertaken here.

### 3.4 `PayrollBatch` (this system's internal batching aggregate — distinct from the GL Engine's `PayRun`) — **built 2026-08-21**, `HR/src/main/kotlin/com/theprodeogroup/hr/domain/staffcost/payroll_batch.kt`, 19 tests

**Naming collision resolved 2026-08-21, before any code existed as this section originally required — named `PayrollBatch`, not `PayRun`.** `PayrollRun` (this section's other candidate) was rejected as still too close in speech/writing to the GL Engine's own `PayRun` (`com.theprodeogroup.fish.domain.payroll.PayRun`) to reliably disambiguate; `PayrollBatch` doesn't share that risk.

**Scope actually built is narrower than this section's full responsibilities list — deliberately, not by oversight.** Built: the worked-vs-leave-funded split (`PayRunLine.compute()`) and totals aggregation (`PayrollBatch.totalWages`/`totalSalaries`), since those are the two pieces this section (and §4) actually resolved in full. `PayRunLine.compute()` takes `grossPay`/`deductions` as caller-supplied, already-computed totals — it does not itself apply `PayrollTaxRule` bands or compute Employer Costs (employer NI/social security, employer pension); that piece of this section's original responsibilities list remains genuinely unresolved, not invented alongside the parts that were ready.

- Selects Employees for a given Company + pay period + frequency — `PayrollBatch.create()`'s `companyId`/`periodStart`/`periodEnd`/`payFrequency`, the actual Employee-selection query itself not built (no repository exists yet in this repo at all).
- For each Employee: gross pay → apply `PayrollTaxRule` bands → apply other Deductions (pension, salary-advance recovery) → net pay — **not built**; composing this from `Employee`/`PayrollTaxRule`/`SalaryAdvance` into the `grossPay`/`deductions` figures `PayRunLine.compute()` takes is left to a future caller. Employer Cost computation likewise not built.
- **Splits worked vs. leave-funded pay, resolved 2026-08-20, now implemented — one Employee's one payslip can produce up to three separate GL Engine calls in the same pay run, not one:**
  1. **Worked portion** — `PayRunLine.workedPortion`, summed into `PayrollBatch.totalWages`/`totalSalaries` (split by `EmploymentType` — `HOURLY` into `totalWages`, `SALARIED` into `totalSalaries`, resolving this section's own "presumably `employmentTerms`-driven" note into a concrete, tested rule). Calling `PostPayRunUseCase` with these totals is application-layer, not built here.
  2. **Leave-funded portion** — `PayRunLine.leaveFundedPortion`, **excluded** from `workedPortion` entirely. `PayrollBatch.linesRequiringLeaveUtilization()` returns exactly the lines a future caller needs to call `UtilizeLeaveAccrualUseCase` for — the call itself not built here either.
  3. **Non-accumulating leave** (e.g. ordinary sick leave) needs no split — folds straight into the caller-supplied `grossPay` before it ever reaches `PayRunLine.compute()`.
  - **Daily-rate conversion and partial-day proration — resolved 2026-08-20, implemented via `Employee.dailyLeaveRate()` (§3.1) called directly from `PayRunLine.compute()`.** Salaried: `daysOnLeave × (salaryRate / standardWorkingDaysPerYear)`. Hourly: `daysOnLeave × hourlyRate × contractedHoursPerDay`. Partial-day proration falls out for free from `daysOnAccumulatingLeave` being a `BigDecimal`, not an `Int` — verified with an explicit half-day test case.
- Sums the worked-portion totals across all Employees in the batch → the two totals → calls `PostPayRunUseCase` — the aggregation (`totalWages`/`totalSalaries`) is built; the actual HTTP call is application-layer, matching `Employee`/`SalaryAdvance`'s own precedent of staying HTTP-unaware domain code.
- **Accrual side, independent of any specific pay run:** calling `RemeasureLeaveAccrualUseCase` per Employee whose accrued-leave target has changed — **not built**, genuinely independent of `PayrollBatch` itself per this section's own framing ("not tied to when leave is taken").

---

## 4. Leave / Absence Tracking

Needed to feed `LeaveAccrual.remeasure()`'s `targetAmount` (the expected cost of unused entitlement) and `utilizeLeave()`'s `amount` (money value of leave taken) — the GL Engine's own `LeaveAccrual` KDoc is explicit that it needs only a Money amount per call, no employee/calendar detail, so this system owns:
- Entitlement accrual rate (e.g. days per month worked).
- Running balance of accumulated-but-unused entitlement per Employee.
- Distinguishing accumulating (carries forward — feeds `LeaveAccrual`) vs. non-accumulating (lapses — no accrual, ordinary Pay Run wages) leave types, matching the categorisation `docs/DDD_Design.md` §2.7 already settled on the GL Engine side.

**How this feeds the pay-run split — resolved 2026-08-20, see §3.4:** per Employee per pay period, this tracking needs to expose days worked vs. days on accumulating leave vs. days on non-accumulating leave, so the batching aggregate can compute the leave-funded money amount for `utilizeLeave()` and exclude it from the worked-portion total. **`daysOnLeave` must be a decimal (`Double`/`BigDecimal`), not an `Int`** — that's what lets §3.4's `daysOnLeave × dailyRate` formula handle partial-day (e.g. half-day) leave correctly with no separate proration mechanism.

---

## 5. Performance Review (scoped 2026-08-20, per the user's "both halves now"; restructured as its own subdomain same day)

Zero financial effect, never posts to the GL Engine, never references FiSH at all beyond sharing `EmployeeId`/`CompanyId` with §3's aggregates. Grounded in `HR/docs/Staff_Appraisal_360_Requirements_Use_Cases.md` (UC-SA1–10, FR-SA01–13, NFR-SA01–05), stored same day.

**Resolved from an initial-looking contradiction, same day.** "Appraisal is Performance Review" (an earlier answer, when Performance Review was still sketched as a Staff Development aggregate) seemed to conflict with the 360° doc's own framing — *"Feeds Staff Development... and HR Payroll"* — since a component can't feed the whole it's part of. **Resolved by precise relationship language, supplied directly by the user: "Appraisal is a subset of Performance Review" (component-of) and "Performance Review feeds Staff Development" (upstream-of).** Appraisal (the 360° self/line-manager/peer/upward gathering-and-aggregation process, UC-SA1–6) is a component *of* `PerformanceReview`. `PerformanceReview` itself — not Appraisal — is what crosses into the other two subdomains: always into Staff Development (a `TrainingRecord`/training request, UC-SA8), optionally into Staff Cost Analysis (a compensation review, UC-SA9). This is why §2 now models Performance Review as its own subdomain rather than nesting it inside Staff Development.

**Every rating in the cycle uses the same fixed 1–5 Likert scale, confirmed 2026-08-20** ("all the input can be reduced to reflect this Likert scale of 1-5") — self-assessment, line-manager, peer, and upward directions all produce 1–5 values; UC-SA6's aggregation is an averaging/rounding operation over same-scale numbers, not a scale-reconciliation problem.

### `PerformanceReview` shape

- `id`, `employeeId`, `periodCovered` (start/end date).
- `selfRating: Int?` — 1–5, nullable (self-assessment is optional/may not be submitted), UC-SA2.
- `lineManagerRating: Int` — 1–5, UC-SA3. **Not anonymised** — attributable to a specific `reviewerId` (another `EmployeeId`), matching the doc's own framing that this direction "is not typically anonymised."
- `peerAggregateRating: Int?` — 1–5, nullable if the minimum-respondent threshold (UC-SA4, FR-SA06) isn't met. **No `List<Int>` of individual peer scores persisted** — FR-SA13 is explicit that individually attributable peer/upward responses are never retained beyond the aggregation step, only the aggregate. The individual inputs that produced this number are ephemeral by design, not a modeling omission.
- `upwardAggregateRating: Int?` — same shape and same non-retention rule as `peerAggregateRating`, UC-SA5. Distinct field (not reused) because its minimum-respondent threshold is separately configured and typically higher (smaller pool, higher sensitivity, per the doc's own note).
- `overallRating: Int` — 1–5, the actual documented outcome from UC-SA7 (the outcome-discussion result agreed by Line Manager + Appraisee) — **not a mechanically computed average** of the fields above; the doc frames UC-SA7 as a discussion informed by all inputs, so this is a distinct, human-determined value, not derived.
- `notes`/`goals` (freeform text) — UC-SA7's "strengths, areas for development, and any agreed objectives."
- Cadence (annual, quarterly, etc.) presumably configurable per Company, not hard-coded.

**Not modeled here, deliberately:** the cycle-setup/nomination machinery (UC-SA1's peer pool, UC-SA5's direct-report identification), the escalation path (UC-SA5/FR-SA08), and the anonymisation mechanism itself (NFR-SA01/02 — this is an infrastructure/access-control concern, not a field on the aggregate). These stay open per §7.

**A genuinely new concern for this codebase: anonymity as a first-class design requirement** (NFR-SA01/02, UC-SA4/UC-SA5's anonymisation-by-default). Nothing built or designed so far in FiSH/GL Engine/HR-Payroll has needed to actively prevent one legitimate user (the Appraisee) from identifying another's input — access control elsewhere in this project has been about *restricting* visibility, not about architecting against *re-identification* from metadata (NFR-SA01's "timing, writing style metadata, or small-pool elimination"). Worth naming explicitly since it's a different kind of requirement than anything else in this document needed.

**A new sibling system recognized, not built — Whistleblowing / Safe Reporting, confirmed 2026-08-20.** The escalation trigger's own tradeoff (a category-based pattern threshold misses a genuinely serious one-off incident reported by only one person) surfaced a real gap. Resolved as **out of scope for Performance Review**: a single-respondent report of serious misconduct — harassment, safety, financial misconduct, safeguarding — isn't specific to the appraisal cycle at all; people need to be able to report it whether or not a 360° review happens to be running. Building it inside Performance Review would either cover only appraisal-adjacent concerns or quietly grow a whole separate system inside this one — the exact trap `docs/DDD_Design.md` §2.7/§2.3 already named for HR/Payroll-vs-GL-Engine and Lending-vs-GL-Engine. Same treatment applies here: **record the decision now, don't build it.** Performance Review's only obligation is that people know this channel exists — likely routing to the same 3-person escalation committee already designed (§7 item 11) once it's actually built, but that's a design question for whenever Whistleblowing/Safe Reporting gets its own scoping pass, not assumed here.

**Zero FiSH involvement, confirmed by the requirements doc's own framing** — *"this module does not post routine financial transactions to FiSH."* Consistent with [[feedback_loose_coupling_high_cohesion]]. **UC-SA9's compensation linkage was decided against 2026-08-20** (Group policy: appraisal and compensation review stay fully separate, protecting appraisal candour) — so Performance Review now has no path into `HR/docs/HR_Payroll_Requirements_Use_Cases.md`'s UC-HR2 at all, not even the master-data-versioning-only path that would have existed either way.

---

## 6. Staff Development

Training/qualification management. Zero financial effect, no GL Engine interaction. Receives training requests from Performance Review outcomes (§5, UC-SA8) — the one thing it consumes from elsewhere in this system.

### `TrainingRecord`

- `id`, `employeeId`, `courseName`, `provider`, `completionDate`, `expiryDate: LocalDate?` (nullable — most training doesn't expire, but compliance-mandated training, e.g. safeguarding or AML certifications relevant to Purse/Osusu staff specifically, does).
- Renewal tracking (flagging when an `expiryDate` is approaching) is a natural query/reporting feature, not a domain-model concern by itself.
- Where sourced from a Performance Review outcome (UC-SA8), the appraisal cycle reference is retained as business justification — pre-populated, not a duplicate manual write-up.

---

## 7. Open Questions (summary — everything flagged `[OPEN]` above, plus system-level ones)

1. ~~Scope of first design/build pass~~ — **resolved 2026-08-20: all three subdomains.**
2. ~~First jurisdiction~~ — **resolved 2026-08-20: jurisdiction-agnostic `PayrollTaxRule` shape, populated with UK + Ireland first.** Actual band/rate figures still needed from an authoritative source (HMRC/Revenue.ie or a licensed service) — not fabricated here, see §3.3.
3. ~~Salary advance disbursement posting~~ — **resolved 2026-08-21: yes, immediate GL posting, as a control account** (Dr Salary Advances/Cr Bank at disbursement, Dr Wages Expense/Cr Salary Advances at recovery, both `EMPLOYEE`-dimension-tagged). See §3.2 for the full resolution and its consequence for `PayRun`'s exclusion list.
4. ~~`PayRun`-vs-`PayRun` naming collision~~ — **resolved 2026-08-21: `PayrollBatch`.** See §3.4.
5. ~~Repo/tech stack~~ — **resolved 2026-08-21: Kotlin/Gradle, matching GL/POP/SOP/IM.** `fish-hr-payroll` scaffolded and building real code (`Employee`, `SalaryAdvance`).
6. **Bank disbursement integration** — does this system initiate actual bank transfers for net pay, or hand off to an external payment rail/provider?
7. ~~Is `PerformanceReview` the same concept as "Appraisal"?~~ — **resolved 2026-08-20: Appraisal is a component of Performance Review (§5).**
8. ~~`PerformanceReview` rating shape~~ — **resolved 2026-08-20: fixed 1–5 Likert scale across every direction (§5).**
9. **One bounded context or three?** (§2) — Staff Cost Analysis, Performance Review, and Staff Development now share only `EmployeeId` (Performance Review's compensation touchpoint into Staff Cost Analysis was decided against, item 11 below); whether that argues for separate deployments is unresolved.
10. **Access control** (§5) — performance/training data is sensitive HR data (adjacent to, but distinct from, the GDPR concerns the payroll requirements doc raises for salary/bank data). Not designed here.
11. **From `HR/docs/Staff_Appraisal_360_Requirements_Use_Cases.md`, all five resolved 2026-08-20:**
    - ~~Peer nomination method~~ — **resolved: hybrid** — eligible peer pool is org-structure-derived, HR Admin randomly selects from within it (neither self-nominated nor manager-hand-picked).
    - ~~Minimum-respondent thresholds~~ — **resolved: 3 for peer, 3 for upward as a hard floor** (upward appraisal doesn't run at all below that, rather than lowering the bar — accepted coverage gap for small teams).
    - ~~Upward-feedback escalation trigger~~ — **resolved: category-based, auto-triggered** on a defined number of independent respondents flagging the same pre-defined serious-concern category, no individual's discretion.
    - ~~Escalation governance~~ — **fully resolved: a small restricted committee** — Head of HR + the safeguarding/compliance role holder + Legal/Compliance counsel (the third seat, chosen for an independent legal-risk perspective distinct from the other two operational roles) — not a single individual; no committee member can unilaterally suppress or dismiss an escalated case.
    - ~~Appraisal-to-compensation linkage (UC-SA9)~~ — **resolved: no linkage.** Appraisal and compensation review stay fully separate as Group policy, protecting appraisal candour. This is why §2 now shows zero touchpoint between Performance Review and Staff Cost Analysis.
    - ~~The one-off-serious-incident reporting gap~~ — **resolved: out of scope for Performance Review.** A general whistleblowing/safe-reporting need, not an appraisal-specific one — recognized as a new sibling system (not built), same treatment as Lending/HR-Payroll's own extraction from the GL Engine. See §5.
    - **All items from `HR/docs/Staff_Appraisal_360_Requirements_Use_Cases.md`'s original open-decisions list, and this document's own follow-on question, are now resolved.**
12. **HR/Payroll's own JWT credential** (§0, new 2026-08-20) — the GL Engine's API only verifies tokens issued by an external IdP, and requires the caller to resolve to a real `User`/`Membership` in FiSH's Tenancy context. How HR/Payroll actually obtains a valid token (a dedicated service-account `User` with a machine-to-machine credential, most likely) is not designed here — a real integration item, not just a detail.

None of these block continuing the design — they block moving from design to code, consistent with the "record the decision, don't build it yet" precedent this whole document follows (`docs/DDD_Design.md` §2.7's own closing line).

---

## 8. Cross-reference against `HR/docs/HR_Payroll_Requirements_Use_Cases.md` (added 2026-08-20, same day)

The user supplied a full requirements/use-case document (UC-HR1–HR12 + cross-cutting requirements) for **The Prodeo Group's own payroll** — Scrip, Purse, Prodeo Capital Ltd, Prodeo Property SPV, UK and Ireland. Stored as reference at `HR/docs/HR_Payroll_Requirements_Use_Cases.md`, same store-over-analyze treatment as Purse Core Banking/Osusu/CFO/iXBRL. This resolves some of §7's open questions and — more importantly — surfaces one direct conflict with already-built GL Engine code.

### 8.1 Questions this resolves

- **Jurisdiction (§7 Q2)** — resolved for *this* consumer of HR/Payroll: UK and Ireland, not agnostic. **Scoped narrowly, though**: this is Prodeo Group's own internal payroll (four named entities), not necessarily the general shape every future B2B tenant needs. §3.3's `PayrollTaxRule` bracket shape should still be built jurisdiction-agnostic (bands as data), just populated with UK PAYE/NI and Irish PAYE/PRSI/USC bands first rather than a third jurisdiction.
- **Entities** — four named FiSH `Company` records: Scrip, Purse, Prodeo Capital Ltd, Prodeo Property SPV. UC-HR1 requires each Employee to map unambiguously to exactly one (or an explicitly-apportioned set of) `CompanyId` — this is a concrete instance of §3.1's `Employee.companyId` field, no longer a placeholder.
- **UC-HR9 (correction/reversal)** — **already fully satisfied by existing GL Engine code**, not a gap. UC-HR9's "never edit directly, generate a full reversing entry, both remain permanently visible" is exactly `JournalEntry.reverse()` + `ReverseJournalEntryUseCase` (`docs/DDD_Design.md` §10.12), built 2026-08-20. HR/Payroll's correction workflow can call that use case directly rather than needing its own reversal mechanism — same free-win pattern as the CFO requirements doc's UC-CFO1 finding (`[[project_cfo_accountant_requirements]]`).
- **UC-HR12 (intercompany recharge)** — flagged in the new doc as "a separate, explicit intercompany journal entry, never embedded inside the payroll posting." Matches the existing parent/consolidation concept already confirmed for `Company` (`[[project_company_relationships_rag]]`) — no new GL Engine mechanism implied, just a caller discipline this system needs to follow.

### 8.2 Direct conflict with already-built code — resolved

**UC-HR4/HR5/HR6 described a liability-first posting pattern that `PayRun.post()` does not implement.** The requirements doc was explicit: *"Payroll should never post net cash movements directly — it posts the obligation. FiSH clears the liability accounts only when disbursement/remittance confirm actual payment."* Concretely, it wanted:

- UC-HR4 (run approved): debit Salary Expense, **credit Net Pay Payable, PAYE Payable, NI/PRSI Payable (employee + employer split), Pension Payable (employee + employer split)** — all liabilities, no cash movement yet.
- UC-HR5 (disbursement, later, separate event): debit Net Pay Payable, credit Cash.
- UC-HR6 (statutory remittance, later still, separate event): debit the relevant Payable, credit Cash.

**What's actually built today** (`GL/src/main/kotlin/.../payroll/pay_run.kt`, confirmed 2026-08-12 per the user's own framing at the time — *"have total wages and salaries debitted to trading and P&L accounts respectively while crediting it to cash or bank account during the payrun"*): `PayRun.post()` debits `totalWages`/`totalSalaries` and **credits cash directly, same entry, same moment — no Net Pay Payable, no PAYE/NI/Pension Payable lines at all.** The KDoc is explicit this was a deliberate simplification, not an oversight: deductions and employer costs are "HR/Payroll's own settlement, entirely outside this posting."

**Resolved 2026-08-20, same day — option 2 chosen, the user's own words: "this should be the ideal position."** `PayRun` stays exactly as built — cash-only, two company-level totals, no liability accounts, no GL Engine changes at all. HR/Payroll owns the itemized obligation tracking (Net Pay, PAYE, NI/PRSI employee+employer, Pension employee+employer) entirely in its own internal records; only the netted `totalWages`/`totalSalaries` cross into FiSH via the already-built `PostPayRunUseCase`. `HR/docs/HR_Payroll_Requirements_Use_Cases.md`'s UC-HR4 is revised accordingly (§8.4 below) rather than `PayRun`.

**Why this is the right call, not just the lower-effort one:** `PayRun`'s cash-only shape was deliberately confirmed by the user back on 2026-08-12 and has 444+ domain tests built against it — reworking it would be a real GL Engine regression risk for a requirement that a *calling* system can satisfy entirely on its own side. The "financial effect only, never operational detail" boundary (`docs/DDD_Design.md` §2.1) that already justified stripping `Employee`/deduction detail out of `PayRun` applies just as cleanly to itemized payable accounts — they're HR/Payroll's own bookkeeping of who's owed what, not a fact FiSH's GL needs to carry as separate line items to remain correct. FiSH still records the true financial effect (total staff cost, total cash out) at the moment it's incurred; it just doesn't need to model the settlement timing gap itself.

### 8.3 Practical implication worth flagging

Because `PayRun.post()` credits cash **at pay-run time**, not at actual disbursement/remittance, FiSH's books will show the full pay-run cash outflow before HR/Payroll has actually paid employees or remitted PAYE/NI/pension. Cross-cutting requirement 5's "dashboard of open payroll liabilities" (§8.4) can no longer be derived from FiSH at all — it has to be a wholly HR/Payroll-internal view, since FiSH has already recognized the cash as gone. One option, not a requirement, already supported by the existing interface with zero FiSH changes: point `PayRun.post()`'s caller-supplied `cashAccountId` at a dedicated "Payroll Clearing" bank account rather than the main operating account, so FiSH at least distinguishes "cash earmarked for payroll" from general operating cash, even though it can't see the itemized breakdown within that.

### 8.4 UC-HR4 revised in `HR/docs/HR_Payroll_Requirements_Use_Cases.md`

The stored requirements doc's UC-HR4 has been amended in place (an `**Amended 2026-08-20**` note added to that document, original text kept and struck through rather than deleted, matching FiSH's own "never silently overwrite" discipline) to match §8.2's resolution:

- HR/Payroll computes gross-to-net and every statutory obligation (Net Pay, PAYE, NI/PRSI employee+employer, Pension employee+employer) and tracks them as liabilities **in its own internal records**, not as FiSH GL accounts.
- Only the two company-level totals (`totalWages`, `totalSalaries`) cross into FiSH, via the existing `PostPayRunUseCase` — unchanged from what's already built.
- UC-HR5 (disbursement) and UC-HR6 (remittance) no longer describe separate FiSH postings that clear a Payable — FiSH already recognized the full cash effect at UC-HR4. They now describe HR/Payroll's own internal obligation-settlement bookkeeping plus the actual bank-rail payment execution, with no further FiSH journal entry.
- Cross-cutting requirement 5 (the "open payroll liabilities" dashboard) is now explicitly an HR/Payroll-internal view, not derivable from FiSH.

### 8.5 Not yet cross-referenced

UC-HR1's multi-entity apportionment, UC-HR3's build-vs-buy tax engine decision, and UC-HR7's single-vs-per-jurisdiction pension provider are the requirements document's own open decisions — carried forward as open, not resolved by anything already built.

---

## 9. Cross-reference against `HR/docs/Staff_Appraisal_360_Requirements_Use_Cases.md` (added 2026-08-20, same day)

The user supplied a full 360° appraisal requirements/use-case document (UC-SA1–10 + FR-SA01–13 + NFR-SA01–05). Stored as reference. Its relationship to `PerformanceReview` is fully worked out in §5 — this section is a pointer, not a duplicate.

### 9.1 Resolution summary

Initially looked like a contradiction against an earlier "Appraisal is Performance Review" answer (a component can't feed the whole it's part of, if "feeds Staff Development" is read literally). Resolved same day by precise relationship language: **Appraisal is a component of `PerformanceReview` (component-of); `PerformanceReview` — not Appraisal — feeds Staff Development, and optionally Staff Cost Analysis (upstream-of).** This is why §2 now models Performance Review as a third, independent subdomain rather than nesting it inside Staff Development. Full reasoning and `PerformanceReview`'s revised shape are in §5.

### 9.2 Not yet cross-referenced

The document's own "open decisions carried forward" (peer nomination method, escalation trigger/governance, minimum-respondent thresholds, the appraisal-to-compensation policy decision) — see §7 item 11, folded in there rather than repeated here.
