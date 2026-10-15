# HR and Payroll: the seam note and the Move 1 build plan

**Status:** HR session, 2026-10-15, for Femi and CM. **Docs only; nothing built.** No code starts until Femi has seen this note and says go. Written to answer, in one pass, CM's order (seam note, then the Move 1 plan) and EA's four questions of 2026-10-15. Evidence tags: **[code]** read in `fish-hr-payroll` master (`7e51428` plus the merged contract tests, 2026-10-15); **[decided]** in the Decisions Log or Femi's words; **[proposal]** my recommendation, for review; **[unverified]** not read or not run.

Sources read: `docs/Payroll_Service_Split_Research_And_Recommendation.md` (the research), `docs/Payroll_SPUTO.md`, `docs/EA_Payroll_Module_Design.md`, `docs/Personnel_Scope_SPUTO.md`, Decisions_Log 2026-10-15, and HR's code.

---

## 1. The seam in one table

| | **Personnel (HR, Administration)** | **Payroll (PAY, Finance)** |
|---|---|---|
| Question it answers | Who works here, since when, doing what, with what leave | What do we owe them, did we pay it, did the ledger and the authorities get it |
| People data | identity, email, employment dates, **pay basis** (salaried, hourly, unpaid), working days and hours, leave | none of it owned; read through one port |
| Money data | none | **pay rate and frequency, bank details**, pay runs and their postings, salary advances, expense claims and their policy, the pay-change audit |
| GL calls | none | all of them (pay run, leave accrual create, remeasure, **utilize**, journal entries) |
| EA permission | module `HR` | module `PAYROLL` (declared in EA, withheld, inert) |
| Keeps from today | employees (identity part), leave, the **Personnel** feature (invite, roles, modules, remove: EA stays the authority behind it), module responsibilities | everything that posts money |

[decided] Femi 2026-10-15: pay basis stays with HR; pay rate, bank details, pay runs, postings to GL, advances and expense reimbursement go to Payroll; request forms stay in People; Personnel (formerly Team) stays in HR.

## 2. Four corrections to the research, found in the code

These change the seam, so they come first. The research said, honestly, that HR should confirm its table against its own knowledge. I did.

1. **There are three crossings, not two.** Leave approval is not a People-only act: approving annual leave **posts a leave-utilization entry to GL**, valued at the employee's daily pay rate (`ApproveLeaveRequestUseCase` calls `employee.dailyLeaveRate()`, `getPayrollPostingContext`, `getOrCreateLeaveAccrual`, `utilizeLeaveAccrual`) [code]. The research said People needs nothing financial from Payroll; that is not so for leave. Leave valuation and posting are money and belong to Payroll; the leave request, balance and approval stay in People. That is a third port (section 4, P3).
2. **"Unpaid leave days" do not exist yet.** The leave types are `ANNUAL` and `SICK` only [code]. What a pay run reads from leave today is the **approved annual-leave days that fall inside the pay period** (they are funded from the leave accrual, so they reduce the wages expense) and the employee's **accrued annual balance as at period end** (`PayrollBatchBuilder`, `LeaveBalanceCalculator.annualBalance`) [code]. The port carries those two figures now; an unpaid-leave count joins it when Personnel gets an unpaid leave type (FR-PEO-06 and 07).
3. **The change-audit table is wholly Payroll's.** `employee_change_audit` accepts only the fields `PAY_RATE`, `PAY_FREQUENCY` and `BANK_DETAILS` (a CHECK constraint, V9) [code]. It moves to Payroll as a whole; Personnel's change history (FR-PEO-12) is a new table later, not a split of this one.
4. **Pay basis and pay terms are welded by an invariant.** `Employee.pay` is a sum type: a paid employment type (salaried, hourly) must have a rate and a frequency, an unpaid one must have neither, enforced in the domain and by a database CHECK (`employees_pay_complete_check`, V10 and V11) [code]. After the split the basis lives in People and the terms in Payroll, so this invariant becomes cross-module (section 5).

Also: **retry of stuck postings is Owner-only today**, not "HR WRITE" as EA's table has it (`RetryPayrollPostingsUseCase` calls `requireOwnerCaller`) [code]. I give the flag-on gate in section 7.

## 3. What moves, table by table and file by file

### 3.1 Tables (all in one database `hr_production` today) [code]

| Table | Owner after the split | Move 1 (code only) | Move 2 (own service) |
|---|---|---|---|
| `employees`: id, company_id, name, email, employment_type, start_date, end_date, standard_working_days_per_year, contracted_hours_per_day | **People** | stays; People's repository reads and writes only these columns | stays in People's database |
| `employees`: pay_rate, pay currency, pay_frequency, bank_details (encrypted) | **Payroll** | stay in the same table, but only Payroll's repository touches them (a second repository over the same row) | move to `employee_pay_terms` (key: employee_id), verified copy, then columns dropped |
| `employee_change_audit` | **Payroll** (whole table, see 2.3) | Payroll's repository only | moves with Payroll |
| `leave_requests` | **People** | unchanged | stays |
| `payroll_run_history`, `payroll_run_submissions`, `payroll_run_submission_lines`, `payroll_run_submission_postings` | **Payroll** | unchanged | move |
| `salary_advances` | **Payroll** | unchanged; its use cases move to the Payroll package | move |
| `expense_claims`, `expense_claim_policies` | **Payroll** | unchanged; use cases move | move |

Foreign keys: `leave_requests`, `expense_claims`, `salary_advances`, `employee_change_audit`, `payroll_run_submission_lines` and `..._postings` all reference `employees(id)` [code]. Move 1 keeps them (one database, nothing to break). **Move 2 must drop the ones that would cross the service line and replace them with a check through the port**; the id is the only link, never a copy under a new id (research risk: a half-split).

### 3.2 Code: where each file goes (package `com.theprodeogroup.hr`)

Today everything is in `domain/staffcost` and one flat `application` package [code]. Proposal: `people`, `payroll` and a small `shared` kernel, each with `domain`, `application`, `infrastructure`.

| Goes to | Files |
|---|---|
| **people** | `employee.kt` (identity half), `employee_email.kt`, `employment_type.kt` (the basis), `leave_*.kt`, `leave_balance_calculator.kt`; use cases `SubmitLeaveRequest`, `ApproveLeaveRequest` (loses its GL calls to a port), `RejectLeaveRequest`, `GetLeaveBalance`, `InviteStaffMember`, `GetTeamMembers`, `RemoveStaffMember`, `GetStaffModuleResponsibilities`, `UpdateStaffModuleResponsibilities`; routes `EmployeeRoutes` (identity part), `LeaveRequestRoutes`, `TeamRoutes`, `StaffResponsibilityRoutes`; EA gateways for the roster and invite proxy |
| **payroll** | `pay_terms.kt`, `pay_frequency.kt`, `payroll_*.kt` (batch, posting, keys, submission, status, tax rule and type), `expense_claim*.kt`, `salary_advance*.kt`, `employee_audit.kt`; `PayrollBatchBuilder`, `PayrollPostingPlanner`, `PayrollPostingExecutor`, `PayrollPostingPayloads`, `PayrollRunOutcomes`, `ApprovalLease`; use cases `SubmitPayrollRun`, `PreviewPayrollRun`, `ApprovePayrollRun`, `RejectPayrollRun`, `RetryPayrollPostings`, `GetPayrollRunSubmission`, `RequestSalaryAdvance`, `ApproveSalaryAdvance`, `RejectSalaryAdvance`, `SubmitExpenseClaim`, `ApproveExpenseClaim`, `RejectExpenseClaim`, `SetExpenseClaimPolicy`, `GetExpenseClaimPolicy`; routes `PayrollRoutes`, `SalaryAdvanceRoutes`, `ExpenseClaimRoutes`, the pay-terms half of `EmployeeRoutes`; the whole GL gateway and its DTOs and the Cognito service-account provider; `field_cipher.kt` (bank details) |
| **shared** (the kernel: imports nothing from People or Payroll) | typed ids (`EmployeeId`, `CompanyId`, the posting and submission ids stay in Payroll), `Money` from `common`, `OwnerCheck`, `HrMembershipAuthorizer` and the EA `/me` gateway (the authorizer gains a module-name parameter, section 7), `Application` wiring helpers, `TenantFromRequest`, the strict JSON and error DTO (`ErrorResponseDto`) |

**The wire does not change in Move 1.** Every URL, request and response stays exactly as it is today; routes are regrouped in two installers, nothing more. The one exception is additive and consumer-first: `selfApproved` (section 7).

## 4. The ports (three, narrow, ids and plain values only)

Ports are interfaces in `shared`-visible `people.api` and `payroll.api` packages. Neither side imports the other's domain or repositories. In Move 1 they are in-process calls inside one transaction scope where today's code is transactional; in Move 2 they become service calls with a service credential, **not through EA** (EA stays the authority for membership only).

| Port | Direction | Carries | Replaces today's |
|---|---|---|---|
| **P1 `EmploymentRecords`** (read) | Payroll reads People | for an employee or a Company and a period: `employeeId`, `companyId`, name, employment type (the basis) and `isPaid`, start and end dates, working days per year, contracted hours per day, **approved annual-leave days inside the period**, **accrued annual-leave balance as at a date** | `employeeRepository.findById/findAllByCompany`, `leaveRequestRepository.findAllByEmployee`, `LeaveBalanceCalculator` calls inside `PayrollBatchBuilder`, `SubmitPayrollRunUseCase`, `RequestSalaryAdvance`, `SubmitExpenseClaim`, the approve use cases |
| **P2 `EmploymentChanged`** (notice) | People tells Payroll | `employeeAdded(employeeId, companyId, basis)`, `employeeBasisChanged(employeeId, basis)`, `employeeEnded(employeeId, endDate)`; plus, at creation, the initial pay terms travel the other way as a call to Payroll's `setInitialPayTerms(employeeId, rate, frequency, bankDetails)` so the unchanged `POST /employees` body still works | `Employee.create` building identity and pay in one step; the pay half of `PUT /employees/{id}` |
| **P3 `LeaveCost`** (call) | People calls Payroll | `recordLeaveTaken(employeeId, days, date, idempotencyKey)` returns the journal entry id or a refusal; Payroll values the days at the daily pay rate and posts the utilization | the GL block inside `ApproveLeaveRequestUseCase` |

Payroll never needs to call People for anything but P1. People calls Payroll only through P2 and P3. Total surface: about eight methods. **That is the measure for the Move 1 check** (section 9).

**P3 and behaviour.** Today approving leave fails with `UtilizationFailed` if GL refuses, and the leave stays PENDING [code]. In Move 1 P3 is a synchronous in-process call and that behaviour is kept exactly. In Move 2 it becomes a service call and I recommend People saves the approval first and Payroll posts with retry, as payroll runs already do; that is a visible behaviour change and a decision for Femi then, not now.

**Neither flow goes through EA.** That answers EA's question 4: your assumption stands. The separate flow (HR pushes an employment to EA, EA pushes to ER, PL-STF-5) is about identity and access, is not built, and is unaffected by this seam.

## 5. The pay-basis invariant after the split

Today: employment type SALARIED or HOURLY implies a rate and frequency; UNPAID implies none [code]. After the split:

- **People** owns the basis and refuses nothing about pay.
- **Payroll** owns the terms and refuses to put an employee on a run, a claim or an advance unless the basis (read through P1) is paid **and** terms exist; the existing refusals (`EmployeeUnpaid`) are kept and a new `pay_terms_not_set` joins them.
- **P2 `employeeBasisChanged`** tells Payroll to require terms (to a paid basis) or clear them (to UNPAID).
- In Move 1 the database CHECK still enforces the weld because both halves still live in the one row; in Move 2 it is re-expressed as the two refusals above and dropped.

Pay-rate, pay-frequency and bank-detail changes stay **Owner Admin only** regardless of the flag [decided, EA design Q3]; they sit in Payroll's code but keep the Owner check.

## 6. Salary advances, expense claims, leave

| Item | Request (the form) | Data and decisions |
|---|---|---|
| Salary advance | People's screen, recorded by whoever may | **Payroll**: table, approval, recovery through the run |
| Expense claim | People's screen | **Payroll**: table, policy limit, approval, reimbursement posting |
| Leave | People | **People**: requests, balances, approval; **valuation and posting through P3 to Payroll** |

**Open decision O1 (recommendation: HR WRITE may also record a request).** EA's design says "record and view" of advances and claims needs PAYROLL WRITE once the flag is on, and HR officers are not given PAYROLL by default (HR_OFFICER: No). Literally applied, an HR officer who records an employee's claim today would be refused the moment the flag is on. I recommend: **recording a request** (create) requires HR WRITE **or** PAYROLL WRITE; **approving, rejecting and reimbursing** require PAYROLL APPROVE. A request is a People act; money is Payroll's. This costs nothing in safety (nothing posts at request time) and keeps today's behaviour for officers. It is Femi's call if he prefers PAYROLL-only.

## 7. The flag `HR_ENFORCE_PAY_SPLIT`: name, scope, default, and EA's questions

**Answer to EA question 1.** The name `HR_ENFORCE_PAY_SPLIT` is confirmed. It does not exist in any repo today (as EA found) and I create it, **default off**. It is a process environment value that CM sets in the task definition, read **once at startup** (a restart changes it), logged at startup, parsed strictly (`true` enables; anything else, including unset, is off). It switches **only the following checks**, nothing else:

| HR routes | Flag off (today, unchanged) | Flag on |
|---|---|---|
| `POST /payroll/run`, `GET /payroll/run-submissions/{id}`, `.../preview`, `GET /payroll/last-run`, `GET /companies/{c}/payroll-run-submissions` | module **HR** at WRITE (reads READ) | module **PAYROLL** at WRITE (reads READ) |
| `POST .../approve`, `POST .../reject` | `requireOwnerCaller` (Owner Admin only) | module **PAYROLL at APPROVE or above**, plus the preparer rule below |
| `POST .../postings/retry` | `requireOwnerCaller` (Owner Admin only; **EA's table said HR WRITE, which is not today's behaviour**) | **PAYROLL at APPROVE or above** (it re-sends an approval's postings); no preparer rule (it is not a decision) |
| `POST /employees/{id}/salary-advances`, `.../expense-claims` (record) | HR WRITE | HR WRITE **or** PAYROLL WRITE (proposal O1) |
| `GET` advances and claims lists | HR READ | HR READ or PAYROLL READ |
| advance and claim approve and reject | Owner Admin only | PAYROLL APPROVE or above plus the preparer rule |
| `PUT /companies/{c}/expense-claim-policy` | Owner Admin only | unchanged |
| `PUT /employees/{id}` pay rate, frequency, bank details | Owner Admin only | unchanged |
| employees, leave (including approve), Personnel, module responsibilities | HR | unchanged |

**Mechanism.** `HrMembershipAuthorizer` hard-codes the module name `"HR"` today [code]; it gains a module parameter. A single `PayrollAccess` policy object, built at startup from the flag, tells each Payroll route which module and level to ask for, so the two modes are one `if` in one place, never scattered. **Both modes are tested for every row of this table** (table-driven: each route × flag off/on × caller types: Owner Admin, PAYROLL APPROVE holder, PAYROLL WRITE holder, HR WRITE holder, a holder of neither). With the flag on, an Owner Admin passes every Payroll row exactly as today because the Owner Admin holds PAYROLL by default (EA design section 3), so **turning it on changes nothing for anyone until someone else is deliberately given PAYROLL APPROVE**.

**Answer to EA question 2: the preparer rule and its reason code.** With the flag on, approving requires that the approver's email differs from the run's `submittedBy`, **except the Owner Admin**, who may approve their own run [decided 2026-10-13: allowed, recorded and flagged]. A non-Owner approver who is also the preparer is refused with **HTTP 403, `error: "forbidden"`, `reason: "preparer_cannot_approve"`** (in HR's existing `ErrorResponseDto.reason` slot, the same one that carries `module_not_granted`). I adopt EA's suggested code. The rule applies to **approve** only; I recommend a preparer may still **reject** their own run (withdrawing it is harmless and a stuck run needs a way out): open decision **O2**.

**`selfApproved`.** When the Owner approves a run they prepared, HR records `selfApproved = true`, decided at approval time and stored (an additive nullable boolean column on `payroll_run_submissions`, next migration V15, and the same pair of columns on `expense_claims` and `salary_advances`), and returns it in the submission response. This is the **one change to a published response**, and it is additive: **consumer first**, EA declares the field in its mirror, then HR ships, then the fixture in `fish-contracts` is regenerated (UC-F3 in the fixtures SPUTO). It does not exist before the flag; with the flag off it is `null`.

For claims and advances the preparer rule needs to know who recorded the request. Today they carry no such field [code]; the same migration adds nullable `submitted_by` to both. A row with no `submitted_by` (every existing row) cannot be tested, so for those the rule does not apply (documented, safe, and temporary: such rows are test data).

**Answer to EA question 3: the approvals list.** **No shape change except `selfApproved`, and HR does not filter by approver.** `GET /companies/{c}/payroll-run-submissions` stays authorized by PAYROLL READ (flag on) and returns the same list. EA already has the caller's own grants from `/me` and the response carries `submittedBy`, so **EA filters its queue**: show a pending run to someone who holds PAYROLL APPROVE at that Company and, unless they are the Owner Admin, hide or mark runs they prepared. Keeping the filter in EA keeps HR's response (a strict contract in `fish-contracts`) unchanged. If EA would rather HR filter, say so and I will add a `?approvableBy=me` query, still without changing the response.

**Answer to EA's unverified point.** The module check is `"HR" in grantedModulesAt(company)` in `HrMembershipAuthorizer.resolve` [code]; a second module name is a parameter, as above; the authorizer's tests need one more case set, not a rewrite.

**What the flag does not do:** it never alters what Owner-only pay changes need, never alters leave, never adds a permission to `/me` (a grant is the string `"PAYROLL"` in `grantedModules`, which HR already holds as a set of strings, so HR's mirror needs no change), and never turns itself on.

**Warning that must go out before the flag is on.** Existing HR WRITE holders do **not** receive PAYROLL [decided]. With the flag on they lose Pay runs, previews and the pay-run list; they keep recording advances and claims only if O1 is accepted. EA's switch-day report lists them; each Business Owner must be told first. This is an operational step, not code.

## 8. The tests that fail on a direct cross-package call

Add before any file moves (red first, then green as the packages appear):

1. **Import-direction test** (a plain Kotlin test that reads `src/main` and checks each file's package and imports; no new dependency): `payroll` may import only `shared` and `people.api`; `people` may import only `shared` and `payroll.api`; `shared` imports neither; `*.api` packages contain only interfaces and plain data classes (no repositories, no Exposed, no `Employee`). A failing example is printed as `payroll/ApproveSalaryAdvanceUseCase.kt imports people.domain.Employee`. (ArchUnit does the same job and is acceptable if CM prefers a library; I recommend the plain test to avoid a new dependency in a money service.)
2. **No cross-owner table access test:** a test that lists, per repository class, the tables and columns it touches and fails if People's repositories touch a Payroll column or the reverse (the pay columns of `employees` are the live case in Move 1).
3. **Idempotency pin:** the keys of pay-run, leave, advance and expense postings are asserted unchanged across the move (they derive from run, leave and record ids, not from packages); a regression here would double-post.
4. **Both-modes authorization table** (section 7) and **the preparer rule** cases, including the Owner self-approval flagged `selfApproved` and a non-Owner preparer refused with `preparer_cannot_approve`.
5. **Wire invariance:** every existing end-to-end route test passes unchanged, and the contract fixtures stay green except the additive `selfApproved`.

## 9. The Move 1 check: how we decide the seam is clean

The research says Move 2 only goes ahead if Move 1 shows a narrow, stable interface. I propose these measurable criteria, written up as the result of step M1-9:

- the three ports total **no more than about eight methods**, carrying only ids and plain values;
- **no Payroll file imports a People domain type** and the reverse, proven by test 1;
- **the only People-to-Payroll call that needs an answer is P3** (leave valuation); everything else is a read or a notice;
- **no table is touched by both sides** (test 2);
- the whole pre-existing suite passes with **no change to a request or response**.

If the leave valuation (P3) turns out chatty, or the pay-basis weld (section 5) needs shared types, that is the signal to stay as two modules.

## 10. Move 1 build plan (ready to start the moment Femi says go)

Each step is its own branch, its own review and its own release, each revertible, and **none changes a URL or a response** except M1-7's additive field. Estimates are mine and unproven; they are for HR's code, tests and migration only, not EA's or WEB's work.

| Step | What | Days | Release |
|---|---|---|---|
| **M1-0** | The import-direction and table-ownership tests, red, with the allowed-import list; the idempotency-key pin test | 0.5 | tests only |
| **M1-1** | Extract the `shared` kernel (ids, `OwnerCheck`, authorizer with a module parameter defaulting to `"HR"`, wiring helpers, error DTO) | 0.5 | refactor |
| **M1-2** | Move files into `people` and `payroll` packages, fix imports, move the tests with them (**a wide mechanical diff: reviewed as such**, grep the diff for wire impact) | 1.0 | refactor |
| **M1-3** | Split the `Employee` aggregate: People's `Employee` (identity, basis, dates, working days) and Payroll's `EmployeePayTerms` (rate, frequency, bank details, the audit), two repositories over the same row, ports P1 and P2, the pay-basis refusals of section 5. **The riskiest step**: `employee.kt`'s `create`, `updated`, audit and `dailyLeaveRate` mix both halves | 1.5 | refactor |
| **M1-4** | P3: leave approval calls `LeaveCost.recordLeaveTaken`; the GL block moves to Payroll; behaviour kept identical | 0.5 | refactor |
| **M1-5** | Advances, claims and the policy move to Payroll; their submit use cases read the employee through P1 | 0.5 | refactor |
| **M1-6** | Regroup routes into two installers, pay-terms handling inside `PUT /employees/{id}` delegated to Payroll; URLs unchanged | 0.5 | refactor |
| **M1-7** | The flag, the `PayrollAccess` policy, PAYROLL checks, the preparer rule, `selfApproved`, `submitted_by`, migration V15; both-modes tests. **Deploy off.** Needs EA's PAYROLL enum live (it is, EA :103) and consumer-first declaration of `selfApproved` | 1.5 | behaviour behind a flag, default off |
| **M1-8** | Regenerate the fixtures for `selfApproved` (EA declares it first), the PAYROLL string in the `me.json` expectations | 0.25 | tests and fixtures |
| **M1-9** | Write the Move 1 check (section 9): ports counted, imports clean, result for CM and Femi | 0.25 | docs |
| | **Total** | **about 7.0** | |

**This is longer than the research's 3 to 4 days.** The research priced the whole of Move 1 across EA, WEB and HR; HR's code alone is about 7 days because of the aggregate split (M1-3), the leave valuation port the research did not know about (M1-4) and test-first discipline on a service that moves money. The EA side (defaults and backfill) and WEB (two tabs) run in parallel and are not in my 7.

**Order and dependencies.** M1-0 to M1-6 can ship in any gap and change nothing visible; M1-7 waits only on EA having declared `selfApproved` and the PAYROLL enum being live; **turning the flag on** waits on EA's step 2 (Owner Admin and Accountant defaults and backfill, after EA's step 1 has been stable) and on Femi's go, and on the switch-day warning to Businesses who lose Pay runs. **No code is started before Femi has seen this note.** I will not enable anything.

**Quality gates for every step:** the full unit and Postgres suites green (Postgres on a port I verified is mine), the contract fixtures green, a reviewer-readable diff, and nothing pushed by me (CM pushes and deploys).

## 11. Move 2, only what this note adds to the research

- Drop the foreign keys that would cross the line (section 3.1) and replace them with the P1 existence checks; move `employee_pay_terms`, the audit, the run, posting, advance and claim tables with a verified row count and checksum; keep the same employee id on both sides.
- The Payroll service gets its **own GL service credential**; the idempotency keys move with the code and include the run id, so a replay stays safe (research section 8).
- P3 becomes asynchronous with retry (section 4, a decision then).
- EA's approvals queue and WEB switch base URL; the contract fixtures' `source` for the pay-run list becomes Payroll and the fixture moves to `contracts/pay/` (until then `source: HR` is correct because the service is still HR).

## 12. Decisions and questions, collected

For **Femi** (via CM, one batch):
- **O1** who may record an advance or claim once the flag is on: HR WRITE or PAYROLL WRITE (recommended) or PAYROLL WRITE only.
- **O2** may a preparer reject their own run (recommended: yes), and does the preparer rule apply to claims and advances as well as pay runs (EA's design says yes; it needs the new `submitted_by`).
- **O3** that Move 1 keeps leave valuation synchronous (as today) and Move 2 revisits it.

For **EA:** declare `selfApproved` in the pay-run mirror first (additive, nullable boolean); filtering of your approvals queue stays on your side (section 7); the reason code is `preparer_cannot_approve`; correct your table's retry row (Owner-only today, PAYROLL APPROVE under the flag).

For **CM:** schedule M1-0 to M1-9 (about 7 d of HR code), arrange the review tier for M1-3 and M1-7 (money, migration), and the release order in section 10.

## 13. What I did not verify

- I did not trace every use of `Employee` outside the files listed; M1-3 will find any I missed, and M1-0's import-direction test is how.
- The Postgres behaviour of the two-repositories-over-one-row design in Move 1 is reasoned, not run.
- How WEB reads the pay terms today (which screen calls which route) was not read; no URL changes in Move 1 is the safeguard.
- Estimates are unproven.
- I have not seen the EA audit record shape (T17) in detail; `selfApproved` here is stored on the row, and the platform audit row is a later task (Payroll SPUTO NFR-PAY-01).
