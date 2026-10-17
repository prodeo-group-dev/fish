PAYROLL PLAYBOOK (draft for Omniview's Playbooks tab, area Payroll; also the Business Owner's acceptance list for the pay screens)

Written by the EA session, 2026-10-17 (Femi: "SPUTOs create playbooks"). Written from EA master 82858d0 (PAYROLL module declared and withheld; `selfApproved` mirror) and HR master 95199c2 (payroll still lives inside HR; Move 1 of the split is being built by the HR session and is NOT on master). Where this sheet says NOT BUILT, believe it over any older document. Nothing here is a promise to a customer.

PLAYBOOK CONTENTS (see docs/Playbook_Definition.md; a playbook is this sheet PLUS the SPUTO set)
1. Operator sheet: this document, sections A to G.
2. Scope: docs/Payroll_SPUTO.md section 1 (what is in and out, jurisdictions).
3. Plan / SRS: docs/Payroll_SPUTO.md section 3 (FR-PAY-01 to 17, NFR-PAY-01 to 09).
4. Use cases: docs/Payroll_SPUTO.md section 5 (UC-PAY-01 to 18) and its "Phone check for the Business Owner's acts".
5. Tasks: docs/Payroll_SPUTO.md section 6 (waves 0 to 5), docs/HR_Payroll_Seam_Note.md (HR's Move 1 steps M1-0 to M1-9).
6. Order: docs/Payroll_SPUTO.md section 6 "Critical path"; the EA rollout order is docs/EA_Payroll_Module_Design.md section 7.
Also: docs/EA_Payroll_Module_Design.md (the PAYROLL module: who holds it, what it gates), docs/Payroll_Service_Split_Research_And_Recommendation.md (why), docs/HR_Payroll_DDD_Design.md (the original payroll design), and the switch-day report (EA scripts/payroll_switch_day_report.sql, copy in docs/reports/Switch_Day/).

A. DECIDED (Femi; Decisions_Log 2026-10-15 and 2026-10-16). Do not re-ask.
- Payroll is split from Human Resources; names "Payroll (PAY)" and "Human Resources (HR)"; the area for HR is "Personnel". Move 1 (two modules inside HR's code) first, Move 2 (own service) before the Live switch if Move 1's check is clean.
- Pay basis stays with HR (Administrative). Pay rate, frequency, bank details, pay runs, ledger postings, salary advances and expense reimbursement are Payroll's (Finance). Request forms stay in Personnel.
- At the switch ONLY Owner Admins and Accountants get the PAYROLL module. Existing HR WRITE holders do not, so each Tenant is warned and told who is affected. Accountant holds it at WRITE.
- Changes to an employee's pay basis, pay rate, pay frequency and bank details are OWNER ADMIN ONLY.
- One access level per assignment applies to all modules in it. A level per module is kept in view (KIV), not scheduled.
- The Owner is the final authority: the Owner Admin may approve their own pay run, recorded and flagged selfApproved. Anyone else cannot approve a run they prepared.
- Withheld PAYE and employer costs are to be recorded in the ledger as liabilities, staged, through GL's generic journal route; the existing PayRun posting is untouched (D-PAY-A: yes).
- FiSH prepares; it does not audit and does not vouch for what a Tenant records (Femi, 2026-10-16). Prodeo is a landlord with no role in any Tenant's payroll data: nothing here lets Prodeo staff read, run or change a Tenant's pay.

B. WHAT THE SYSTEM DOES TODAY (flag off; PAYROLL does not gate anything)
- A pay run is prepared in HR (POST /payroll/run) by anyone holding the HR module at WRITE at that Company, previewed, then approved or rejected. Approve, reject and retry are OWNER ADMIN ONLY (identity test from the caller's own /me). Salary advances and expense claims are Owner-only to approve and reject in the same way.
- Each pay-run line carries gross pay and a deductions figure THE OFFICER TYPES. Nothing computes PAYE or social insurance. The run is checked only for deductions not above gross.
- The ledger posting is net-based: the cash movement is posted, withheld PAYE and employer costs appear nowhere as expense or liability. The "what do I owe the tax authority" figure cannot come from the ledger today.
- EA knows a module value PAYROLL (declared 2026-10-15) but it is withheld from every grant: no role holds it, an invite or a modules change that asks for it is refused with 422 module_not_yet_available, and GET /me never lists it. It is safe: it gates nothing yet.
- EA's approvals queue lists pending HR payroll runs for the Owner Admin (read-only; the approval is done in HR). EA's mirror already declares HR's additive selfApproved field, so the day HR starts sending it nothing breaks.

C. COMMON QUESTIONS AND HOW TO ANSWER
Q: "I run payroll today; will I still be able to after the switch?"
A: Only if you are an Owner Admin or an Accountant at that Company. Anyone else who holds HR at WRITE loses Pay runs on the day PAYROLL is enabled until the Owner Admin grants it. The Owner Admin is warned beforehand with the list of who is affected. Until the switch day nothing changes.
Q: "Can an HR officer approve a pay run?"
A: Not today (Owner Admin only). After enforcement: only a holder of PAYROLL at APPROVE or above, and never the person who prepared that run unless they are the Owner Admin.
Q: "The Owner prepared and approved the same run. Is that allowed?"
A: Yes, by decision (the Owner is the final authority). It is recorded and flagged selfApproved so it can be seen. A non-Owner doing the same is refused (planned reason preparer_cannot_approve; not live yet).
Q: "Who can see or change bank details and pay rates?"
A: Owner Admin only. The people records in Personnel never show bank details.
Q: "Where is PAYE computed?"
A: Nowhere yet. The officer types the deductions figure. Computed PAYE (UK and Ireland first) is designed and ordered but NOT BUILT.
Q: "Why does the ledger not show what we owe HMRC / Revenue / NASSIT?"
A: Because only the net cash movement is posted today. Liability-first posting is decided and staged but NOT BUILT.
Q: "I invited someone as Payroll and got 422."
A: module_not_yet_available. PAYROLL cannot be granted until the switch. Do not promise a date; Femi announces it.
Q: "A pay run is stuck in approving."
A: A crash mid-approval leaves it resumable. The Owner Admin uses Retry (same keys, no duplicate postings). Escalate to the HR session with the run id and the Company id; do not ask for a database edit.

D. ERROR TOKENS YOU WILL SEE
module_not_yet_available (EA, 422). forbidden (EA or HR, 403: signed in but not allowed). payroll_run_submission_not_found (HR, also used for "not your Company"). unauthorized (401). Planned, not live: preparer_cannot_approve (403).

E. WHAT TO COLLECT BEFORE ESCALATING
The person's role (not their name in a ticket if avoidable), the Company id, the run id, the exact action and the error token, and the time. Never ask for a bank detail, a tax ID, a password or a token. Never ask anyone to read a payroll figure aloud to Prodeo: Prodeo has no role in a Tenant's pay.

F. ACCEPTANCE LIST: THE PHONE CHECK FOR THE BUSINESS OWNER'S ACTS
Source: Femi, 2026-10-15: the Business Owner can run the business from a mobile device; this list is the playbook's acceptance test for every payroll screen the Owner uses. WEB runs each check on a phone (about 400 px wide, mobile preset) before the screen ships; EA's SPUTO text is Payroll_SPUTO.md "Phone check". A screen passes only if EVERY check passes. Result column values: Pass, Fail, Not built, Not yet tested. As of 2026-10-17 no payroll screen has been phone-checked and the Owner approval screens below are Not yet tested (the existing pay-run screens were built for a desktop).

General checks (apply to every Owner act):
- PH-1 One screen: at phone width one screen shows who, what, the effect in money or access, and what happens next. No sideways scrolling to understand it. Pass when no horizontal scrollbar appears and all four are visible by scrolling down only.
- PH-2 Two-step decision: after reading the screen the Owner chooses Approve or Reject. A reason is REQUIRED on reject, optional on approve. Pass when no extra step works only on a desktop.
- PH-3 Long lists are cards or summaries with a way to open detail, never a wide table scrolled sideways. Pass when a 30-employee run shows as a summary plus openable detail.
- PH-4 Notices carry no figures and no names ("3 items need you"); the detail appears only after sign-in. Pass when an email or push text contains neither.
- PH-5 Online only: nothing of the business's data is stored on the phone (no cache, no database, no offline queue); a payslip or statement is saved only by a deliberate PDF download, which is audited. Pass when storage is empty after use and the download appears in the audit trail.
- PH-6 Confirmation and audit: the result is confirmed on the same screen and audited, including a flagged self-approval. Pass when the confirmation shows and the audit row exists with actor, Company, action, selfApproved and request key (docs/EA_Audit_Record_Shape_T17.md).
- PH-7 Plain failure: a failed or partial result says in plain words what happened and what to do (for example Retry), never a bare error code. Pass when every error token in section D has a plain sentence on the phone.

Per-act checks (the one screen must show this; decision as stated):
- PAY-ACC-1 Set pay terms and bank details (UC-PAY-02): the person, what changes (rate, frequency, bank), the effect on the next run; bank details masked until the Owner asks to see them. Decision: Save or Cancel.
- PAY-ACC-2 Preview and approve a pay run (UC-PAY-05, 07): period, number of people, total gross, each kind of deduction, employer cost, net, the ledger effect, who prepared it, any overrides with their reasons. Decision: Approve or Reject. A self-approval is shown as flagged before the Owner confirms.
- PAY-ACC-3 Reject a pay run (UC-PAY-08): the same summary. Decision: Reject with a required reason.
- PAY-ACC-4 See what is owed to authorities (UC-PAY-10): per body due, remitted, outstanding, overdue; opens detail. No decision (read). NOT BUILT.
- PAY-ACC-5 Record a remittance above the limit (UC-PAY-11, D-PAY-E): body, period, amount due, amount entered, the difference. Decision: Approve or Reject. NOT BUILT; the limit is undecided.
- PAY-ACC-6 Correct a posted run (UC-PAY-15): what was posted, what changes, the adjusting amount. Decision: Approve or Reject. NOT BUILT.
- PAY-ACC-7 Approve a salary advance or an expense claim (UC-PAY-16, 17): who, how much, the reason, the recovery or reimbursement plan. Decision: Approve or Reject.

Switch-day acceptance (EA and CM, no phone needed):
- SW-1 The switch-day report ran on production and its counts were given to each affected Tenant's Owner Admin before the switch.
- SW-2 After the switch every Owner Admin and every Accountant (not revoked) holds PAYROLL; nobody else does; the count equals the report's complement.
- SW-3 An Owner Admin who prepared and approved a run sees it flagged selfApproved.
- SW-4 Turning HR's enforcement flag on changes nothing for an Owner Admin (property from the module design, section 5).

G. NOT BUILT, NOT DEPLOYED OR NOT YET EXERCISED (as of 2026-10-17)
- PAYROLL module granted to anyone; the Owner Admin / Accountant backfill; the switch-day warning to Owner Admins: prepared inert in EA (tests first), NOT enabled (Femi announces).
- HR's code split into Personnel and Payroll packages, the HR_ENFORCE_PAY_SPLIT flag and the PAYROLL checks on payroll routes, the preparer-is-not-approver rule, selfApproved emitted by HR: HR's Move 1, in progress, not on master.
- Payroll as its own service (Move 2): scheduled after Move 1's check; not started.
- EA's approvals queue showing runs to PAYROLL APPROVE holders (not only the Owner Admin): waits on HR's list contract.
- Computed PAYE and employer costs, effective-dated rule sets, year-to-date records, tax profiles, remittance, reconciliation, statutory schedules, payslips, corrections, liability-first ledger posting: designed (Payroll_SPUTO waves 3 and 4), none built. Real PAYE rules (tax codes, credits, cumulative basis) are not in the repo's reference docs and must be sourced first.
- Sierra Leone PAYE thresholds: unit (old versus new Leone) unconfirmed.
- Per-module access levels: KIV.
- No payroll screen has been phone-checked.
