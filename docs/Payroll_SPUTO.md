# Payroll: the full SPUTO (split, permissions, PAYE accounting and management)

**Status:** 2026-10-15, planning only, nothing built. Written by the EA session at Femi's request ("A full SPUTO will be required to get the Payroll playbook ... including accounting and managing PAYE deductions"). **Owner of this document: EA, as integrator.** HR, GL, WEB and CM own their own tasks; each task here is a proposal for its owner to confirm. Evidence tags: **[code]** read on `origin/master` of HR, GL, EA or WEB on 2026-10-15; **[doc]** read in a repo doc; **[decided]** in the Decisions_Log or a decided doc; **[unverified]** not read or not sourced.

SPUTO formalises decisions already made; it does not re-make them. Already decided and **not re-litigated here**: the split in two moves, the names Payroll (PAY) and Human Resources (HR), pay basis with HR and the run with Finance, advances and expense claims with Payroll, RBAC as the driver (`docs/Payroll_Service_Split_Research_And_Recommendation.md`, Decisions_Log 2026-10-15); the EA module design (`docs/EA_Payroll_Module_Design.md`, merged); tax computation built in-house, pension per jurisdiction, single entity per employee, runs started by hand (HR backlog D1 to D4, 2026-10-01). **One earlier decision is reopened by the new PAYE-accounting request and is put to Femi as a decision, not assumed: section 4, D-PAY-A.**

---

## 1. Scope (S)

**The problem.** Payroll is the most sensitive and most regulated thing FiSH does for a business. Today it lives inside HR, is approved by an identity test (Owner Admin), accepts a hand-typed "deductions" figure, and puts only a netted cash movement in the ledger. Femi wants it separated (RBAC), and wants PAYE deductions properly **accounted** (in the books) and **managed** (computed, tracked, remitted, reported).

**In scope**
1. **Split:** Personnel (HR) and Payroll (PAY): first as two modules in one service (Move 1), then, if the seam is clean, as its own service before the Live switch (Move 2).
2. **Permissions:** the EA module `PAYROLL`; three separate permissions (set pay basis, run payroll, approve a pay run); preparer is not approver; enforced later behind `HR_ENFORCE_PAY_SPLIT`.
3. **PAYE and other statutory deductions, end to end:** compute (PAYE, social insurance such as NI, PRSI, USC, NASSIT; employee and employer sides), **account** (expense and liabilities in the ledger), **manage** (year-to-date records, amounts due, remittance, reconciliation, schedules, payslips, corrections).
4. Salary advances and expense claims as Payroll's money-out flows.

**Out of scope (named so nobody assumes it):** filing to a tax authority by API (HMRC RTI, Revenue ROS; that is `docs/External_Regulatory_And_Banking_API_Integrations_Requirements_Specification.md`, later; this SPUTO only leaves the hook); pension scheme administration beyond the deduction and remittance line (D3: per jurisdiction, own later pass); paying employees through a bank (HR backlog Epic 8); performance reviews; multi-entity apportionment (D1: no); automatic scheduled runs (D4: manual).

**Jurisdictions.** Real, sourced figures exist as reference data for UK, Ireland, Sierra Leone, Liberia, Guinea, Côte d'Ivoire and Nigeria (`docs/<CC>/..._Tax_And_Currency_Settings.md`). **Only SLE is onboarded as a Mano River currency** [decided 2026-08-22], so Liberia, Guinea, Côte d'Ivoire and Nigeria rule data stays reference-only until a currency decision changes. UK and Ireland (GBP, EUR) are the first computation targets named in HR's own docs.

---

## 2. What is true today (evidence)

| # | Finding | Tag |
|---|---|---|
| E1 | A pay run line carries `grossPay` and a **caller-typed** `deductions` total. Nothing computes PAYE; `PayrollBatchBuilder`/`PayrollBatch.compute` only check `deductions <= grossPay`. | [code] `SubmitPayrollRunUseCase.LineInput`, `payroll_batch.kt` |
| E2 | `PayrollTaxRule` (bands by jurisdiction and `PayrollTaxType`) exists and is tested, but has **no repository, no effective date, no caller**, and is deliberately unpopulated. | [code] `payroll_tax_rule.kt`; [doc] HR_Payroll_DDD_Design §3.3 |
| E3 | The ledger posting is **net-based**: the wage and salary expense is built from `workedPortion = netPay - leaveFunded - recovery`, and the whole pay run credits cash in one posting. Withheld PAYE and employer costs therefore appear **nowhere** in the ledger, as neither expense nor liability. I read the code; I did not run it. | [code] `payroll_batch.kt` lines 99-111, `PayrollPostingPlanner.kt` |
| E4 | GL's payroll posting context knows only these accounts: wages expense, salaries expense, cash, accrued-leave liability, leave expense. **No** PAYE, NI, pension or net-pay payable, and no employer-cost expense. | [code] `ComputePayrollPostingContextUseCase.kt` |
| E5 | The 2026-08-20 design chose "cash-only, HR tracks the itemised obligations internally" and itself noted the consequence: FiSH's books show the cash gone before anyone is paid or remitted, and a dashboard of open payroll liabilities cannot come from the ledger. | [doc] HR_Payroll_DDD_Design §8.2, §8.3 |
| E6 | **Not built:** `Employee.jurisdiction`, a tax ID or tax code field, employer-cost computation, year-to-date records, remittance schedules, remittance posting, payslips. | [doc] HR backlog Epics 2, 6, 7, 12; [code] no matching files |
| E7 | HR's MVP definition treats statutory computation and remittance as **Enhancement**: an accountant computes PAYE outside the system and the officer types the figure. | [doc] HR_MVP_Definition |
| E8 | The reference figures are **bands and rates only**. Real PAYE is not a pure function of one period's pay: the UK uses a tax code and cumulative year-to-date basis, Ireland uses the employee's credits and cut-off (RPN) on a cumulative basis, and each jurisdiction has its own tax year. Those rules are **not in the repo's reference docs**. | [doc] reference docs read; the rules themselves are general knowledge, [unverified], to be sourced |
| E9 | SL's PAYE band **thresholds** are reported inconsistently (old Leone versus New Leone); the YAML marks `thresholdUnitConfirmed: false`. | [doc] `docs/SL/SL_Tax_And_Currency_Settings.md` |
| E10 | The approval path is already crash-safe: an approval lease, deterministic idempotency keys per posting, resume and retry. New posting kinds must use the same planner. | [code] `ApprovalLease.kt`, `PayrollPostingPlanner.kt`, `PayrollPostingExecutor.kt` |
| E11 | HR's existing backlog already holds the PAYE-related epics (2 compute, 6 remittance, 7 payslips, 12 tax ID, 4 adjustments, 1 advances); this SPUTO orders them with the split rather than duplicating them. | [doc] `HR/docs/HR_Payroll_Product_Backlog.md` |
| E12 | Today no HR session is running among the peers I can message (WEB, CM and GL are); HR-owned tasks below need an owner session. | [unverified] ListAgents on 2026-10-15 |

---

## 3. Requirements (P): SRS-style, MoSCoW

**Functional (FR-PAY-n)**

| ID | Requirement | MoSCoW |
|---|---|---|
| FR-PAY-01 | Payroll is its own module (`PAYROLL`) and screen group (Finance); Personnel stays in Administration. | Must |
| FR-PAY-02 | Three permissions are separate: set pay basis (HR), run payroll (PAYROLL WRITE), approve a pay run (PAYROLL APPROVE). | Must |
| FR-PAY-03 | A non-Owner approver may not approve a run they prepared; the Owner may, and it is recorded and flagged `selfApproved`. | Must |
| FR-PAY-04 | Pay terms (rate, frequency, bank details) are Payroll's and Owner-Admin-controlled; the HR side never reads bank details. | Must |
| FR-PAY-05 | Each employee has a tax profile: jurisdiction, tax ID, and the jurisdiction's PAYE inputs (for example a tax code, credits). The tax ID is encrypted at rest (Epic 12 on Epic 5). | Must (for computed PAYE) |
| FR-PAY-06 | Statutory rule sets are **effective-dated** per jurisdiction and tax type; a run uses the rule set in force for its pay date, and the run **records which rule-set version it used**. | Must |
| FR-PAY-07 | A run **computes** per employee: taxable pay, PAYE (honouring the jurisdiction's cumulative or non-cumulative basis), employee social insurance, other statutory deductions, employer social insurance and employer pension, advance recovery, net pay. The officer may see and, with a reason, override a figure. | Must for UK and IE go-live; Should otherwise (see D-PAY-D) |
| FR-PAY-08 | **Year-to-date totals** per employee (gross, taxable, PAYE, employee and employer contributions) are kept and used for the cumulative basis and year-end reports. | Must (with FR-PAY-07) |
| FR-PAY-09 | **Ledger accounting of an approved run** (subject to D-PAY-A): gross staff cost and employer costs as expense; net pay payable; PAYE payable; social insurance payable (employee and employer); pension payable; each a separately named liability account in the Company's chart. | Must (if D-PAY-A = liability-first) |
| FR-PAY-10 | **Remittance:** the officer sees amounts due per statutory body and period, records a remittance (date, amount, reference), and the ledger clears the matching payable against cash. Over- and under-payment are visible. | Must |
| FR-PAY-11 | **Reconciliation:** each payable account's ledger balance equals the sum of un-remitted amounts due; a mismatch is reported, never silently adjusted. | Must |
| FR-PAY-12 | **Statutory schedules** (per employee PAYE and contribution lines per period) are exportable per jurisdiction format (D3: shape varies by jurisdiction). | Should |
| FR-PAY-13 | **Payslips** show gross, each deduction, net, year-to-date; delivered through a protected channel only (never an open email attachment); every download is audited. | Should (employment-law floor in the UK, per the HR MVP note) |
| FR-PAY-14 | Corrections and reversals (a mistaken run, a late change) produce visible adjusting entries and an adjusted amount due, never an edit of a posted figure. | Should |
| FR-PAY-15 | Salary advances: request in Personnel, approve and recover in Payroll through the run; expense claims: request in Personnel, reimburse in Payroll. | Must |
| FR-PAY-16 | Reports for the Owner: staff cost, PAYE and contributions owed, amounts remitted, next due, and anything overdue, by Company and period. | Should |
| FR-PAY-17 | Hooks for later filing (the pay run and remittance data shaped so an RTI or ROS submission can be built from it), no filing now. | Could |

**Non-functional (NFR-PAY-n)**

| ID | Requirement |
|---|---|
| NFR-PAY-01 | Every money-moving or access-changing act is audited with the platform shape (`docs/reports/Playbooks/EA/EA_Audit_Record_Shape_T17.md`): actor, Company, action, `selfApproved`, request key; same transaction as the act; append-only. |
| NFR-PAY-02 | Every ledger posting stays idempotent and replay-safe: new posting kinds join `PayrollPostingPlanner`'s keyed plan, resume and retry exactly as today. |
| NFR-PAY-03 | Money is `Money` (amount and currency), decimal arithmetic with a stated rounding rule per jurisdiction (rounding of PAYE to the penny or whole unit is a rule, not an accident). |
| NFR-PAY-04 | Pay data is the most sensitive data held: least privilege between Personnel and Payroll (own service identity and database role after Move 2), bank details and tax IDs encrypted, no figures in notifications or logs. |
| NFR-PAY-05 | Strict decoding on every cross-service payload (consumer-first, contract fixtures in `fish-contracts` from day one, never `ignoreUnknownKeys`). |
| NFR-PAY-06 | Rule data is reproducible: a past run can be recomputed from its recorded rule-set version and inputs. |
| NFR-PAY-07 | Retention of payroll and statutory records at least the legal minimum per jurisdiction. The periods are **not sourced here**; they are a question for Femi, not a number I will supply. |
| NFR-PAY-08 | Strangler discipline for the split: each step is a separately revertible release; never a half-split (one employee id across both sides, no copies). |
| NFR-PAY-09 | **Phone check:** every act the Business Owner performs passes the phone check in section 5 (one screen, two-step decision, no wide tables, no figures in notices, online only, confirmed and audited). |

---

## 4. Decisions, and the one that is reopened

**D-PAY-A: how PAYE appears in the ledger (reopens HR_Payroll_DDD_Design §8.2, decided 2026-08-20).** Evidence E3 to E5 show that today the ledger carries only a net cash movement, so staff cost looks smaller than it is and nothing says what is owed to the tax authority. The new request ("accounting and managing PAYE deductions") cannot be met by the cash-only design. Two options:

| Option | What posts at approval | Cost | Effect |
|---|---|---|---|
| **K (keep)** | Net pay as today; HR keeps the itemised liabilities in its own tables. | None. | Books understate staff cost and hide the PAYE liability; the "what do I owe" dashboard must be a Payroll-internal view, not the ledger. |
| **L (liability-first, recommended)** | Debit gross staff cost and employer costs; credit net pay payable, PAYE payable, social insurance payable, pension payable. Disbursement and remittance later clear the payables against cash (separate postings). | GL needs a way to post these (its generic journal-entry route already exists and HR already calls it [code `ktor_gl_engine_gateway.kt`]; the **real work is account roles** in the posting context and the chart of accounts template, plus a new posting kind per clearing). The existing `PayRun` posting and its 444+ tests need not change if HR posts the liabilities through the generic journal; that is the low-risk path. | Books are correct for any accountant; the owner's "owed to tax" figure comes from the ledger; reconciliation (FR-PAY-11) becomes possible. |

Recommendation: **L, staged**: first approve the account roles and the journal shape (GL, tests first), then post gross-and-liabilities beside the existing posting behind a flag, then retire the net-only posting. This is a decision for Femi because it changes what the ledger says about every payroll customer; I did not assume it.

Other decisions (asked in section 8): D-PAY-B jurisdictions first; D-PAY-C who owns and signs off statutory rule data each tax year; D-PAY-D whether computed PAYE is a go-live gate or stays an Enhancement with manual entry; plus the four PAYROLL questions already put to Femi.

---

## 5. Use cases (U)

Actor names: **Officer** (prepares), **Approver**, **Owner Admin**, **Accountant**, **HR Officer**, **System**. Each use case is one capability; the preconditions all include "caller holds the module named" and, for ledger acts, an open period and configured accounts.

| UC | Name | Actor and module | Main flow (short) | Postconditions and alternates | Traces |
|---|---|---|---|---|---|
| UC-PAY-01 | Set a pay basis | HR Officer, HR | Choose time, salaried, piece, contract for an employee. | Basis stored in Personnel; Payroll sees it via the crossing read. Pay rate, frequency and bank details are separate (UC-PAY-02). | FR-PAY-02, 04 |
| UC-PAY-02 | Set pay terms and bank details | Owner Admin, PAYROLL | Enter rate, frequency, bank details. | Encrypted at rest; only the Owner Admin sees bank details; audited. | FR-PAY-04, NFR-PAY-04 |
| UC-PAY-03 | Maintain an employee's tax profile | Owner Admin or Officer, PAYROLL | Record jurisdiction, tax ID, PAYE inputs. | Refused if the jurisdiction's currency is not onboarded or inputs are missing (names what is missing). | FR-PAY-05 |
| UC-PAY-04 | Prepare a pay run | Officer, PAYROLL WRITE | Choose Company, period, date; System reads employment records and unpaid-leave days; computes each line (FR-PAY-07). | Run is PENDING with its rule-set version; duplicate period refused; unpaid employees excluded. | FR-PAY-06, 07, 08, 15 |
| UC-PAY-05 | Preview a run | Officer, PAYROLL READ | See gross, each deduction, employer cost, net, per employee and total, and the ledger effect. | Nothing is posted. | FR-PAY-07, 09 |
| UC-PAY-06 | Override a computed figure | Officer, PAYROLL WRITE | Change a line with a required reason. | Override and reason audited and shown to the approver. | FR-PAY-07, NFR-PAY-01 |
| UC-PAY-07 | Approve a pay run | Approver, PAYROLL APPROVE | Review preview; approve; System takes the approval lease and posts (FR-PAY-09). | Run APPROVED when every posting succeeded; a crash leaves APPROVING and resumable; preparer is refused unless Owner (flagged). | FR-PAY-02, 03, 09, NFR-PAY-02 |
| UC-PAY-08 | Reject a pay run | Approver, PAYROLL APPROVE | Reject with reason. | Nothing posted; preparer notified; run closed. | FR-PAY-02 |
| UC-PAY-09 | Retry or resume stuck postings | Officer or Approver, PAYROLL | Retry the run's failed postings. | Same keys, same bodies; no duplicates. | NFR-PAY-02 |
| UC-PAY-10 | View what is owed to authorities | Owner Admin or Accountant, PAYROLL READ | Per body and period: due, remitted, outstanding, overdue. | Figures equal the ledger (FR-PAY-11). | FR-PAY-10, 11, 16 |
| UC-PAY-11 | Record a remittance | Accountant, PAYROLL WRITE (APPROVE above a limit, D-PAY-E) | Enter body, period, amount, date, reference. | Payable cleared against cash in the ledger; short or over payment shown. | FR-PAY-10 |
| UC-PAY-12 | Reconcile payables to the ledger | Accountant, PAYROLL READ | System compares each payable account to un-remitted dues. | Mismatch reported with the difference; nothing adjusted automatically. | FR-PAY-11 |
| UC-PAY-13 | Export a statutory schedule | Officer, PAYROLL READ | Choose jurisdiction, period, format. | File shaped per jurisdiction; audited as a download. | FR-PAY-12 |
| UC-PAY-14 | Issue a payslip | System, delivered to the employee | After approval, produce a payslip; deliver through the protected channel. | Download audited; none by open email attachment. | FR-PAY-13 |
| UC-PAY-15 | Correct a posted run | Approver, PAYROLL APPROVE | Create an adjusting run for the difference. | Visible adjustment; amounts due updated; original untouched. | FR-PAY-14 |
| UC-PAY-16 | Request and recover a salary advance | Employee requests (Personnel); Approver approves; Payroll recovers in later runs | Advance approved; recovery appears as a deduction line. | Balance reaches zero; ledger effect per D-PAY-A. | FR-PAY-15 |
| UC-PAY-17 | Reimburse an expense claim | Approver, PAYROLL APPROVE | Approve; reimburse through a run or a payment. | Posting and audit. | FR-PAY-15 |
| UC-PAY-18 | Maintain statutory rule sets | Platform operator or a named finance role (D-PAY-C) | Add the next tax year's rule set with an effective date and source. | Existing runs keep their recorded version; the new set applies from its date. | FR-PAY-06, NFR-PAY-06 |

---

### Phone check for the Business Owner's acts

**Phone check (Femi, 2026-10-15: the Business Owner can run the business from a mobile device).** An act the Business Owner performs passes only if all of these hold. WEB tests each one on a phone before it ships; the playbook for this area inherits the table below as its acceptance list.

1. **One screen** at phone width (WEB's tests used about 400 px) shows who, what, the effect in money or access, and what happens next. No sideways scrolling to understand it.
2. **Two-step decision:** after reading that screen the Owner chooses Approve or Reject (a reason is required on reject, optional on approve). No second step that only works on a desktop.
3. **Long lists are cards or summaries** with a way to open the detail, never a wide table that must be scrolled sideways.
4. **Notices carry no figures and no names** ("3 items need you"); the detail appears only after sign-in.
5. **Online only:** nothing of the business's data is stored on the phone.
6. **The result is confirmed on the same screen and audited**, including a flagged self-approval.
7. **A failed or partial result says in plain words what happened and what to do** (for example Retry), never a bare error code.

| Owner act | What the one screen shows | Decision |
|---|---|---|
| UC-PAY-02 set pay terms and bank details | The person, what changes (rate, frequency, bank), the effect on the next run; bank details masked until the Owner asks to see them | Save or Cancel |
| UC-PAY-05 and 07 preview and approve a pay run | Period, number of people, total gross, each kind of deduction, employer cost, net, and the ledger effect; who prepared it; any overrides with their reasons | Approve or Reject |
| UC-PAY-08 reject a pay run | The same summary | Reject with a required reason |
| UC-PAY-10 see what is owed to authorities | Per body: due, remitted, outstanding, overdue; opens detail | No decision (read) |
| UC-PAY-11 record a remittance (above the limit, D-PAY-E) | Body, period, amount due, amount entered, the difference | Approve or Reject |
| UC-PAY-15 correct a posted run | What was posted, what changes, the adjusting amount | Approve or Reject |
| UC-PAY-16 and 17 approve a salary advance or an expense claim | Who, how much, the reason, the recovery or reimbursement plan | Approve or Reject |

---

## 6. Tasks (T) and order (O): one dependency-ordered backlog

Owner column: **EA, GL, HR, WEB, CM, Femi**. HR tasks need an owner session (E12). Each code task is tests-first, one commit, reviewed and released by CM. `#` order is not dependency order; read the Depends column.

### Wave 0: decisions and docs (no code; start now, in parallel)

| # | Item | Owner | Depends on |
|---|---|---|---|
| 0.1 | The four PAYROLL module questions, D-PAY-A, B, C, D, E (section 8) | Femi, via CM | none |
| 0.2 | HR seam note: section 5 of the research note made exact: two crossing flows, what each table becomes, what is Personnel's and Payroll's | HR | none |
| 0.3 | Tax-rule sourcing note: UK tax code and cumulative basis, Irish credits and RPN, SL personal reliefs, per-jurisdiction tax year, rounding, remittance due dates, retention periods, each with a source; SL threshold unit resolved or kept flagged | HR (with Femi for sources) | none |
| 0.4 | PAYE accounting design note: account roles, journal shape for approval, disbursement, remittance, correction; chart template additions | GL (with HR) | 0.1 (D-PAY-A) |
| 0.5 | Confirm or assign an owner session for HR work | CM, Femi | none |

### Wave 1: consumer-first and foundations (small, safe, independent)

| # | Item | Owner | Depends on |
|---|---|---|---|
| 1.1 | Add `PAYROLL` to GL's `ManagedModule` and make the `/me` decode fail closed (unknown module = no access) | GL | none |
| 1.2 | `PAYROLL` label and hint in `moduleLabels.ts`; check the Team module chooser | WEB | none |
| 1.3 | EA ships `PAYROLL` in the enum **inert** (no default, no backfill), with tests and the contract fixture example | EA | 1.1 live |
| 1.4 | Effective-dated rule-set shape and persistence (Epic 2.1, extended with effective date, source, version) with seed from the reference YAMLs | HR | 0.3 |

### Wave 2: Move 1, the seam (no behaviour change)

| # | Item | Owner | Depends on |
|---|---|---|---|
| 2.1 | Split HR's code into Personnel and Payroll packages with a narrow interface and architecture tests that fail on a direct cross-package call | HR | 0.2 |
| 2.2 | EA defaults and backfill for `PAYROLL` per Femi's answers (Owner Admin, ACCOUNTANT; backfill for existing HR WRITE holders per Q2) | EA, CM | 1.3 stable, 0.1 |
| 2.3 | Tabs: Personnel under Administration, Payroll under Finance | WEB | 2.1 |
| 2.4 | `HR_ENFORCE_PAY_SPLIT` flag and the PAYROLL checks on payroll routes, default off (design: `EA_Payroll_Module_Design.md` §6) | HR | 2.1, 2.2 |
| 2.5 | Move 1 check: is the interface narrow and stable? Written result | HR, CM | 2.1 to 2.4 |

### Wave 3: PAYE computed and accounted (inside the Payroll package)

| # | Item | Owner | Depends on |
|---|---|---|---|
| 3.1 | Employee tax profile: jurisdiction, tax ID (encrypted), PAYE inputs (Epics 12, 5.1 and 2.2) | HR | 0.3, 2.1 |
| 3.2 | Year-to-date store per employee | HR | 3.1 |
| 3.3 | Computation engine for UK and Ireland first (D-PAY-B): PAYE on the correct basis, employee and employer social insurance, USC, rounding; every run records its rule-set version; manual override with reason | HR | 1.4, 3.1, 3.2 |
| 3.4 | Account roles for PAYE, NI/social, pension, net-pay payables and employer-cost expense in the posting context and chart template | GL | 0.4 |
| 3.5 | Liability-first posting at approval behind a flag, as new posting kinds in `PayrollPostingPlanner`; disbursement clearing posting; old net-only posting retired after verification | HR, GL | 3.3, 3.4, 0.1 (D-PAY-A = L) |
| 3.6 | Contract fixtures for every new cross-service payload (HR to GL, Personnel to Payroll) | HR, GL, EA | with 3.5 |
| 3.7 | Employer-cost computation (Epic 2.3) | HR | 3.3 |
| 3.8 | WEB: preview shows each deduction and the ledger effect; override with reason; tax profile form | WEB | 3.3 |

### Wave 4: managing it (owed, remitted, reconciled, reported)

| # | Item | Owner | Depends on |
|---|---|---|---|
| 4.1 | Amounts-due store and the "owed to authorities" read (UC-PAY-10) | HR (Payroll package) | 3.5 |
| 4.2 | Remittance recording and its ledger posting (UC-PAY-11) | HR, GL | 4.1 |
| 4.3 | Reconciliation report (UC-PAY-12) | HR, GL | 4.2 |
| 4.4 | Statutory schedules per jurisdiction (Epic 6; D3) | HR | 4.1, 3.1 |
| 4.5 | Payslips and protected delivery (Epic 7; audited download) | HR, WEB | 3.3, Epic 5 channel |
| 4.6 | Corrections and adjusting runs (Epic 4, UC-PAY-15) | HR | 3.5 |
| 4.7 | Owner view of staff cost and PAYE owed | WEB, EA (dashboard tile source) | 4.1 |
| 4.8 | Audit rows for every act above in the T17 shape | HR, EA (shape) | T17 approved |

### Wave 5: enforce, then split

| # | Item | Owner | Depends on |
|---|---|---|---|
| 5.1 | Turn `HR_ENFORCE_PAY_SPLIT` on per environment | CM, Femi | 2.5, 4.8 |
| 5.2 | Move 2: Payroll as its own service (`fish-payroll`), before the Live switch, only if 2.5 is clean: verified table copy, credentials and idempotency keys moved, EA approvals queue and WEB repointed, infrastructure, backup and recovery on the Live checklist | CM, HR, EA, WEB | 2.5 clean, 5.1 |

**Kept in view (KIV), not scheduled:** per-module access levels (Femi, 2026-10-15). One access level per assignment is accepted; triggers and cost are in `docs/EA_Payroll_Module_Design.md` section 4 (KIV). **Answered 2026-10-15:** D-PAY-A yes (liability first, staged, through GL's generic journal route, PayRun untouched); the four PAYROLL questions (only Owner Admins and Accountants get PAYROLL at the switch, pay basis and rate and bank changes Owner Admin only, one level per assignment). D-PAY-B to E remain open.

**Critical path:** 0.1 and 0.2, then 2.1, then 3.1 to 3.3, with 0.4 and 3.4 in parallel for the ledger side, then 3.5, 4.1 to 4.3. Compute inside the Payroll package after the seam so PAYE is not built twice and moved.

**Rollback notes:** `PAYROLL` rows in EA cannot be read by an older EA build (backfill only after the release is stable); the liability-first posting runs beside the old one behind a flag until a month of runs reconciles; Move 2 steps are independent, revertible releases.

---

## 7. Risks

- **Bands are not PAYE (E8).** Without tax codes, credits and cumulative handling, computed PAYE is wrong for real UK and Irish employees. Sourcing (task 0.3) must precede the engine; the engine must not ship on bands alone.
- **Changing what the ledger says (D-PAY-A).** Every existing payroll customer's books change shape; run both postings side by side and reconcile before retiring the old one.
- **A half-split.** Both sides need one employee id (never a copy); crossing payloads are fixture-tested from day one.
- **Rule data is legal data.** A wrong or stale rate is a compliance failure; sign-off and effective dating (D-PAY-C, FR-PAY-06) are product features, not admin chores.
- **SL.** PAYE threshold unit is unresolved (E9); SL computation waits on that, even though SL is the market wedge.
- **No owner for HR work today (E12).**

## 8. Decisions asked of Femi (one batch, via CM)

Already asked and unchanged: the four PAYROLL questions in `EA_Payroll_Module_Design.md` section 9.

New:
1. **D-PAY-A:** account for PAYE in the ledger liability-first (recommended, staged, option L), or keep the net-only posting (option K)?
2. **D-PAY-B:** which jurisdictions get computed PAYE first? Recommended: UK and Ireland (their rules are sourced and HR's docs name them), Sierra Leone after its threshold unit is resolved; Liberia, Guinea, Côte d'Ivoire and Nigeria stay reference-only until their currencies are onboarded.
3. **D-PAY-C:** who owns the statutory rule data and signs off each new tax year's figures (a named finance person, or the platform operator through Omniview)?
4. **D-PAY-D:** is computed PAYE a go-live gate for UK and Irish customers (recommended: yes, since manual entry puts compliance risk on the customer), or does manual entry stay acceptable for the first customers as HR's MVP note says?
5. **D-PAY-E:** may an Accountant record a remittance of any size, or is a larger remittance an approval (Owner or approver)?

## 9. What I could not verify

- The actual PAYE, tax code, credit, cumulative and due-date rules per jurisdiction; I know them only generally and they are **not** in the repo's reference docs (E8). They must be sourced, not taken from this note.
- Whether the Company chart-of-accounts templates already contain payable accounts for PAYE, NI or pension; whether GL's generic journal route accepts the multi-line shape task 3.5 needs without change.
- How `totalWages` and `totalSalaries` are exactly derived beyond lines 99 to 111 of `payroll_batch.kt` (E3 is my reading, not a test run).
- HR's expense-claim and salary-advance internals beyond their route lists; whether an HR session exists but was not listed.
- Legal retention periods and employment-law payslip duties for each jurisdiction.
- Production data of any kind.
