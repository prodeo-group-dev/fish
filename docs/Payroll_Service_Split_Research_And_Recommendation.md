# Splitting Payroll out of HR: research and recommendation

Status: CM research and recommendation, 2026-10-15, for Femi. Planning only; nothing built or started. Prompted by Femi (2026-10-15): "We may need to separate Payroll into its own service. I see HR being in Administration and Payroll in Finance. It reduces the incidences of conflating purposes." Evidence tags: **[code]** read in `fish-hr-payroll` origin/master (47619ca) on 2026-10-15; **[decided]** a decision already in the Decisions_Log; **[estimate]** CM's unproven estimate; **[opinion]** judgement.


## 0. The driver is RBAC (Femi, 2026-10-15)

Asked what drives the split, Femi answered: "RBAC". That sharpens the recommendation. In FiSH every EA module (GL, SOP, POP, IM, HR, TAX, EDUCATION_RUNTIME) is one service with its own membership check (`GET /me`, per-Company access level and granted modules). A person's access is then a plain assignment: "this role holds this module at this Company". Today HR and payroll share one module, so "may administer people" and "may run or approve pay" cannot be granted separately without custom checks inside one service. Giving Payroll its own module (and, in step two, its own service) makes the permission split the platform's normal mechanism instead of a special case. Deferred-enforcement still applies (flag HR_ENFORCE_PAY_SPLIT, design now, turn on after the features, RBAC freeze respected).

## 1. Recommendation in one paragraph

**Yes: separate them, in two moves, and do the physical split before the Live switch.** The first step that matters for RBAC is a separate EA module `PAYROLL` (design now, enforce later behind the flag); the service split follows the platform rule of one module, one service. Move 1 (about 3 to 4 days, no new infrastructure): draw the seam inside HR now, as two modules with two permissions and two screens (People under Administration, Payroll under Finance). Move 2 (about 6 to 9 days **[estimate]**): turn the Payroll module into its own service while every row is still test data. The purpose argument you give is sound, and it matches what is already decided (pay basis Administrative, pay run Finance). The reason to do Move 2 now rather than later is cost: moving live payroll data between databases and services after real use is slow and risky, and today it is free. I would not make the split a service *unless* Move 1 shows the two sides can talk through a narrow, stable interface (section 5); if it shows chatty coupling, stay as two modules and revisit.

## 2. What HR contains today **[code]**

One service, one database (`hr_production`), 14 migrations, about 260 tests, live. Its use cases fall into five groups:

| Group | Contents | Belongs to |
|---|---|---|
| People records | employees (name, email, employment type, start and end date, working days and hours), change audit, the staff team views and module responsibilities (a proxy to EA) | Administration (HR) |
| Time off | leave requests, approvals, leave balance and entitlement | Administration (HR) |
| Pay terms | pay rate, pay frequency, employment type (salaried, hourly, unpaid), bank details (encrypted at rest) stored on the employee row | the seam: pay **basis** is Administrative [decided 2026-10-13]; bank details and pay rate are used only by payroll |
| Money out to staff | pay run submit, preview, approve, reject, retry; posting to GL (pay run, leave accrual remeasure and utilise); salary advances; expense claims and their policy | Finance (Payroll) |
| Staff-cost analysis | gross-to-net computation, statutory deductions (`PayrollTaxRule`), leave accrual valuation | Finance (Payroll) |

Outside HR, three things depend on it: EA (the approvals queue reads payroll runs awaiting approval), WEB (one tab, "People": Employees, Pay runs, Salary advances, Team) and GL (HR is its caller through a service credential; GL does not call HR).

## 3. Why the split is right (your argument, tested)

1. **Two purposes are already tangled in one tab and one service.** "Team", "Add employee" and "Run payroll" sit side by side, and the tester found mixed words ("Employees", "Pay runs", "Salary advances", "Team"). One person who administers people is not necessarily the one who may run or approve pay.
2. **The permission split you decided needs a seam.** Set pay basis (Administrative), run payroll and approve a pay run (Finance, different people) are three separate permissions [decided 2026-10-13]. Today the approve action is "Owner Admin only" and "run" has no Finance concept; enforcement is deferred behind a flag (HR_ENFORCE_PAY_SPLIT). A boundary in the code makes the permissions natural instead of a patch.
3. **Pay data is the most sensitive data we hold about people** (rates, bank details, deductions). Isolating it behind its own service identity and database role means a defect or a stolen credential in the people side cannot read it, and the HR side never needs bank details.
4. **It matches the division model** [decided 2026-10-13]: Administrative, Operations, Finance. Payroll sits with Finance next to the ledger it posts to.

## 4. Why not simply "do nothing" or "split later"

- **Cost grows with real data.** A split with test data is a migration script we can rerun. With live payroll it needs a freeze, reconciliation and rollback.
- **Each new service has a running cost we have felt** **[opinion from this project's history]**: a container service, a load-balancer rule, a database and role on the shared instance, a Jenkins job (one build node today), infrastructure code, an EA module and membership checks, the contract fixtures, the Cache-Control, idempotency and strict-mirror rules. Seven services already carry these; an eighth is real work and ongoing upkeep. That is the argument for Move 1 first and a hard look before Move 2.

## 5. Where the seam falls, and what has to cross it

Payroll needs from People: who is employed and from when to when, their division, pay terms, and unpaid-leave days in the period. People needs from Payroll: nothing financial, except possibly a "paid" marker for display.

Proposed ownership **[opinion]**:

| Data | Owner after the split | Why |
|---|---|---|
| Employee identity, employment dates, division, pay **basis** (salaried, hourly, unpaid; later piece or contract) | People (HR) | Administrative, decided |
| Pay rate and frequency actually used to compute a run, bank details | Payroll | only payroll uses them; least privilege |
| Leave requests and balances | People (HR) | an HR process; payroll reads "unpaid days in period" |
| Salary advances | Payroll | money to staff; deducted in a run; requested by the employee in People's screen, approved in Finance |
| Expense claims and policy | Payroll for reimbursement; request form in People | reimbursement is a payment |
| Pay runs, postings to GL, statutory rules, accrual | Payroll | |

Two crossing flows, both small and stable: (1) a read of "employment records and unpaid leave days for period P" (People to Payroll); (2) an "employee added, changed or ended" notice (People to Payroll) so Payroll's own pay-terms record exists. Pay terms entered by whom? The basis in People (Administrative); the rate in Payroll (Finance), which is exactly the separation of duties you want.

## 6. Options compared

| Option | Description | Effort **[estimate]** | Verdict |
|---|---|---|---|
| A | Stay one service, move the screen only (People under Administration, Payroll under Finance) | 1 to 2 days (WEB + labels) | cheap but does not draw the boundary in code or data |
| B | One service, two modules and two permissions (Move 1) | 3 to 4 days (HR code seam, EA permission design, WEB tabs, tests) | do now |
| C | Two services (Move 2) | 6 to 9 days after B: new repo from HR's skeleton, Flyway move of the pay tables with a verified copy, service credential and GL posting identity move, Terraform and Jenkins, EA module and membership, WEB base URL, contract fixtures, EA approvals queue repoint, runbook | do before Live, if B shows a clean seam |

## 7. Move 1, in order (all docs first, RBAC changes deferred behind flags)

1. HR: write the seam note (the table in section 5 made precise: ports for the two crossing flows; what each table becomes). Docs only.
2. EA: design the permission or module split (a Finance-side payroll capability; today the approve action is Owner-only) [RBAC freeze: design now, enforce later behind HR_ENFORCE_PAY_SPLIT].
3. HR: split the code into two packages with an interface between them; Payroll code may read employment data only through it; add tests that fail on a direct cross-package call.
4. WEB: People under Administration, Payroll under Finance; the shared Staff directory reads both.
5. Check: does the interface stay narrow and stable? Only then go to Move 2.

## 8. Move 2, in order (only if Move 1's check passes)

New repo and service `payroll` (name to confirm; Femi prefers "edusys"-style short names, so `fish-payroll`); copy pay tables with a verified row count and checksum; move the GL posting credential and the idempotency keys with the code (the keys include the run id, so replays stay safe); EA approvals queue and WEB pointed at the new service; HR drops the moved tables after a clean week. Each step is an independent, revertible release.

## 9. Risks

- **A half-split is worse than either end.** Both sides need the same employee id across services: use the existing employee id, never a copy under a new one.
- **A strict decode of a mismatched shape after a side effect** (the class of failure found on 2026-09-29 and 2026-10-12): fixture-tested from day one.
- **The money-out flows (advances, expense claims) cross both sides.** Decide their home explicitly (table above); do not let them straddle.
- **Operations load:** one Jenkins node and a shared database instance; both are fine for one more small service, but add it to the Live-switch checklist (backup and recovery for the new database).

## 10. Decisions for Femi

1. Approve Move 1 (module split, tabs, permission design) now? Recommended: yes.
2. Approve the principle "Payroll becomes its own service before the Live switch, if Move 1's check passes"? Recommended: yes.
3. Confirm where salary advances and expense claims live (Payroll, with the request screens in People)? Recommended: yes.
4. Name: `payroll` or something shorter? (Naming only.)

## 11. What this document does not claim

Estimates are unproven; no code was changed; coupling beyond the files read (batch builder, use cases, routes list) has not been traced line by line; the HR session should confirm the table in section 5 against its own knowledge before anything starts.
