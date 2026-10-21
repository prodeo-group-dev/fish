# EA module PAYROLL: design (docs only, nothing built)

**Status:** 2026-10-15. Design only. Written by the EA session for the payroll split Femi approved on 2026-10-15 (Decisions_Log; research `docs/Payroll_Service_Split_Research_And_Recommendation.md`). **Enforcement is built later, behind `HR_ENFORCE_PAY_SPLIT`; the RBAC freeze is respected: nothing in this note changes who can do what today.** Facts below were read on `origin/master` of EA, HR, GL and WEB on 2026-10-15; anything I did not read is marked *unverified*. Decisions asked of Femi (through CM) are in section 9.

**Superseded in part, 2026-10-21 (Femi, Decisions_Log 2026-10-20/21):** HR may read, prepare and request; **approve, reject, retry and resume of a pay run are the Business Owner (Owner Admin) ONLY, not PAYROLL APPROVE holders**; only Payroll runs the payroll, after that approval. Where this note says a PAYROLL APPROVE holder approves, read "the Owner Admin". Sections 2, 5 and 6 below are corrected; the PAYROLL module and its defaults are unchanged.

**Answered 2026-10-15 (Femi, via CM; Decisions_Log):** Q1 and Q2: **only Owner Admins and Accountants get PAYROLL at the switch; existing HR WRITE holders do NOT** (so the switch-day checklist must warn each Tenant and list who loses Pay runs; EA's read-only report `EA/scripts/payroll_switch_day_report.sql` produces the counts). Q3: pay basis, rate, frequency and bank-detail changes are **Owner Admin only, unchanged**. Q4: **one access level per assignment is accepted for now** (constraint C1 stands). ACCOUNTANT is treated as holding PAYROLL at **WRITE** unless Femi corrects it. D-PAY-A (liability-first ledger accounting) is answered yes in the Payroll SPUTO. Self-approval stays as decided (Owner may, flagged; non-Owner may not).

## 1. Facts that shape the design

| Fact | Where | Why it matters |
|---|---|---|
| `ManagedModule` is GL, HR, SOP, POP, IM, TAX, EDUCATION_RUNTIME. A grant is `CompanyRoleAssignment(role, accessLevel, grantedModules)` per Company; the module column is `VARCHAR(20)` ("PAYROLL" is 7 characters). | EA `managed_module.kt`, migration V15 | A new value needs no schema change. |
| `AccessLevel` is NONE, READ, WRITE, **APPROVE**, ADMIN, ordered; ONE level per assignment, applying to all of its modules. | EA `access_level.kt` | "Approve" already exists as a level. The only limit is that it is not per module (section 4, constraint C1). |
| Defaults: `defaultModulesFor(OWNER_ADMIN)` = every module except EDUCATION_RUNTIME; ACCOUNTANT = GL and TAX; HR_OFFICER = HR. `RegisterCompanyUseCase.assignOwnerAdminsAt` also grants "all but EDUCATION_RUNTIME" with level ADMIN. Every ordinary role defaults to WRITE. | EA `membership.kt`, `RegisterCompanyUseCase.kt` | Adding PAYROLL to the enum changes who holds it the moment either default is derived from `entries`. That must be deliberate (section 3). |
| HR's payroll routes (`POST /payroll/run`, preview, run-submissions) check the **HR** module at WRITE through `authorizeHrForWrite`. | HR `PayrollRoutes.kt`, `Auth.kt` | Today the preparer is anyone with HR WRITE. |
| HR's payroll approve, reject and retry are **Owner Admin only**, decided per request from the caller's own `GET /me` (`requireOwnerCaller` reads `isOwnerAdmin` for the block that contains the run's Company). Expense claims and salary advances are Owner-only the same way; so is a change to pay rate, pay frequency or bank details. | HR `OwnerCheck.kt`, `ApprovePayrollRunUseCase.kt` | The approve gate is an identity test, not a permission. The split turns it into a permission without changing who passes it today. |
| HR already records who prepared a run: `submittedBy = caller email` on submit. HR's `authorizeHrForApprove` (level APPROVE) exists and is used by Leave. | HR `PayrollRoutes.kt`, `Auth.kt` | "Preparer is not approver" has its input already. |
| **`HR_ENFORCE_PAY_SPLIT` does not exist in any repo yet.** I searched HR (code, docs, terraform) and Infrastructure on master and found nothing; the name comes from the research note. | grep, 2026-10-15 | Whoever builds it (HR, with CM for the environment value) creates it. This design only names what it must switch (section 6). |
| Femi's decided rules: pay basis is Administrative (HR); the pay run given a basis is Financial (D21, 2026-10-13); the Owner is the final authority and may approve their own request, recorded and flagged (2026-10-13); only the Owner Admin sees bank details (2026-10-06); preparer is not approver (2026-10-15). | Decisions_Log | These are inputs, not questions. |

## 2. What the module is

`PAYROLL` is a **Company-level grant** to the money-out half of today's HR module. It is held per Company like every other module, and read from `GET /me` unchanged (it is just another string in `grantedModules`).

| Capability | Module and level (after the flag is on) | Today (flag off) |
|---|---|---|
| **Set a pay basis** (time, piece, salary, contract; D21) | **HR** at WRITE (propose) and at ADMIN or the Owner Admin to change an existing employee's basis (see Q3) | HR WRITE for employee records; the Owner Admin only for pay rate, frequency, bank details |
| **Prepare a pay run** (and preview it) | **HR at WRITE or PAYROLL at WRITE** (HR may also read pay runs) | HR at WRITE |
| **Approve a pay run** (approve, reject, retry, resume; this posts to the ledger) | **Owner Admin ONLY** (a PAYROLL APPROVE grant does not confer it); the Owner may approve a run they prepared, flagged `selfApproved` | Owner Admin only |
| Salary advances and expense claims: record and view | HR WRITE or PAYROLL WRITE (the request forms stay in Personnel, per the decision) | HR WRITE |
| Salary advances and expense claims: approve or reject | Owner Admin only, same rule as a pay run (HR confirming the doors) | Owner Admin only |
| See or change bank details | **Owner Admin only**, not a module permission (unchanged) | same |
| Employee records, leave, division, `employeeId` | HR (unchanged) | same |

So the decided permissions map to (corrected 2026-10-21): set pay basis = HR; prepare a pay run = HR WRITE or PAYROLL WRITE; approve, reject, retry or resume a pay run = the Owner Admin only (no PAYROLL APPROVE needed). No new permission concept or `/me` field is needed. Capability lists on `/me` (RBAC plan T5a) are not required for this.

PAYROLL grants nothing in the Education Runtime; it never interacts with EDUCATION_RUNTIME, and a school Company's Owner Admin holds it exactly as any Company's does.

## 3. Who holds it by default

| Role | PAYROLL by default | Level by default | Reason |
|---|---|---|---|
| OWNER_ADMIN | **Yes** | ADMIN (already) | The Owner is the final authority. Both `defaultModulesFor(OWNER_ADMIN)` and `assignOwnerAdminsAt` derive "all but EDUCATION_RUNTIME" from `ManagedModule.entries`, so they would grant PAYROLL **automatically**; this is the intended result but it must be pinned by a test, not left to a side effect. |
| ACCOUNTANT | **Yes (proposed)** | WRITE: prepares runs; APPROVE is an explicit grant | D21 says the run is Financial; this puts it with the money role. (Femi, 2026-10-18: the Accountant default also includes IM, so an accountant can set product VAT categories and record opening stock; add-only, built in EA branch feat/ea-accountant-im-default, with its own dry-run-first backfill.) |
| HR_OFFICER | **No** | n/a | An HR officer owns people records and pay basis; also holding the run and the approval is exactly the single-person risk the split exists to remove. |
| SALES_OFFICER, PURCHASING_OFFICER, INVENTORY_MANAGER | No | n/a | Nothing to do with pay. |

An explicit grant (the access controls in Personnel, or the module-change route) can still give PAYROLL to any role, as it can any module today. Defaults are only defaults.

## 4. Constraints I found (not solved here)

- **C1. One access level per assignment** (matters less since 2026-10-21: no one but the Owner Admin approves a pay run, so "approves payroll only" is no longer a need). An ACCOUNTANT holding GL, TAX and PAYROLL at APPROVE would also be at APPROVE for GL and TAX. That is probably acceptable for a trusted approver, but it is not "approve payroll only". A per-module level is a larger change to the access model (RBAC freeze, Femi and CM decide). Recommendation: accept C1 for Move 1; revisit if a customer needs "approves payroll but not ledger entries".
- **KIV (kept in view, not scheduled, not built) - per-module access levels** (Femi, 2026-10-15: "Per module must be a KIV"). One level per assignment is accepted for now; a level per module within an assignment is kept in view. **What would trigger it:** (a) a real customer needs someone to approve payroll who must NOT hold APPROVE on GL or TAX at the same Company, or the reverse; (b) an auditor or security review of the live platform names the shared level as a finding; (c) a second module (Personnel, a future one) needs a level different from its neighbours in the same assignment. **What it would cost** (mine, unproven): EA's `CompanyRoleAssignment` and its table, a migration, an additive field on `GET /me` (consumer first: GL, SOP, POP, IM, HR strict mirrors, plus `fish-contracts` fixtures), the access controls in Personnel (WEB), and CM review under the RBAC freeze; roughly 4 to 6 days in EA and half a day to a day in each consumer.
- **C2. One assignment per Company per Membership** appears to hold (`assignAt` replaces; *unverified*), so a person cannot be "WRITE for HR and APPROVE for PAYROLL" in two rows. Same answer as C1.
- **C3. Rollback hazard.** EA decodes stored module rows with `ManagedModule.valueOf`; once a `PAYROLL` row exists in `membership_assignment_modules`, an older EA build that does not know it would fail to read that Membership. **Do not backfill PAYROLL rows until the EA release carrying the enum is stable**, and treat a backfill as a point of no easy return (rollback would need the rows deleted first).

## 5. How today's Owner-only approve is handled

1. **Now (flag off): nothing changes.** HR keeps `requireOwnerCaller` for approve, reject, retry, advances, claims. PAYROLL exists in EA's vocabulary but gates nothing.
2. **When the flag is on (corrected 2026-10-21):** the approve, reject, retry and resume routes **stay Owner Admin only**; the prepare door accepts HR WRITE or PAYROLL WRITE. *(The earlier text here made them require PAYROLL at APPROVE; that is superseded.)* The rest of this item, kept for the record: ~~(a) module PAYROLL at level APPROVE or above at the run's Company, through the same `/me` block lookup HR already uses, and (b) the preparer rule below.~~ The flip therefore changes who may PREPARE (HR and PAYROLL holders) and changes nothing about who may approve. That is the property that makes the flag safe to turn on.
3. **Only the Owner approves; self-approval is flagged:** the Owner Admin may approve a run they prepared themselves; it is then recorded with `selfApproved = true` in the audit record (the shape in `EA_Audit_Record_Shape_T17.md`) and shown to the Owner as flagged, matching the 2026-10-13 rule ("self-approval is allowed and is recorded and flagged"). Anyone else who tries to approve, reject, retry or resume gets 403 with a machine-readable reason (HR's `insufficient_access` / `preparer_cannot_approve`).
4. **Bank details and "pay rate, frequency, bank details" changes stay Owner Admin only** until Femi says otherwise (Q3).
5. EA's own approvals queue (`ComposeApprovalsQueueUseCase`) lists HR payroll runs for the Owner, who is the only approver. **Showing them to a PAYROLL APPROVE holder is withdrawn** (queue item 4 is now only about what the Owner sees).

## 6. Enforcement behind `HR_ENFORCE_PAY_SPLIT` (build later)

The flag is HR's (an environment value CM sets; default off). It switches **only** these checks, route by route:

| HR routes | Off (today) | On |
|---|---|---|
| `POST /payroll/run`, `.../preview` | HR module, WRITE | HR WRITE **or** PAYROLL WRITE |
| `GET /payroll/run-submissions/...`, `GET /payroll/last-run`, `GET /companies/{c}/payroll-run-submissions` | HR module, READ | HR READ or PAYROLL READ |
| `.../postings/retry` (and resume) | Owner Admin only | Owner Admin only (corrected 2026-10-21) |
| `POST /payroll/run-submissions/{id}/approve` and `/reject` | `requireOwnerCaller` | **Owner Admin only** (corrected 2026-10-21; was PAYROLL APPROVE + preparer rule) |
| `POST /employees/{id}/salary-advances`, `/expense-claims` (request) | HR WRITE | HR WRITE or PAYROLL WRITE |
| their approve/reject | Owner-only | Owner Admin only (HR confirming the doors) |
| `PUT /companies/{c}/expense-claim-policy` | Owner-only | unchanged (Owner-only) |
| Employees, leave, team, module responsibilities | HR | HR (unchanged) |

Not-built-yet items this needs, in order of EA's work: nothing in EA beyond the enum value and the defaults in section 3 (EA already stores and returns any module string). EA's own routes that validate a module name (`ManagedModule.valueOf` in `TenantRoutes.kt` for invite and module change) accept PAYROLL automatically once the enum has it. Tests EA owns when it builds: the three default-grant paths (Owner at registration, `defaultModulesFor`, backfill), module-change route accepts and persists PAYROLL, `/me` returns it, and a contract fixture.

## 7. Rollout order (consumer-first; strict decode)

GL decodes every module string from `GET /me` with `ManagedModule.valueOf` (`ktor_ea_membership_gateway.kt`, line 73 on master). An unknown value throws on **every authorized GL request for that Company**: this is exactly the 2026-09-29 EDUCATION_RUNTIME incident. SOP, POP, IM and HR hold `grantedModules` as a list or set of strings, so they tolerate a new value without a code change. WEB shows an unknown module as its raw code (`moduleLabel` falls back to the code, never hides it) but has no word for it yet.

| Step | Who | What | Gate |
|---|---|---|---|
| 0 | **GL** | Add `PAYROLL` to GL's own `ManagedModule` (the same one-line fix as EDUCATION_RUNTIME). **Also recommend making the `/me` decode defensive:** an unknown module string is treated as "no access to that module" (fail closed), never an exception. That is not the forbidden `ignoreUnknownKeys` (which concerns unknown JSON keys and silently ignoring them); it keeps strict key decoding and turns an unknown *value* into a denial instead of a 500. GL's decision; I recommend it because it removes this whole class of incident. | Must be **live** before step 2 |
| 0b | SOP, POP, IM, HR | Declare nothing new in code (already `List<String>`); add `PAYROLL` to their contract-fixture expectations only when step 1 lands. HR's authorizer later reads `"PAYROLL" in grantedModulesAt(...)`. | none |
| 0c | **WEB** | Add `PAYROLL: 'Payroll'` and a hint ("pay runs and approval") to `moduleLabels.ts` (generic and school vocabulary; a school keeps the word Payroll unless ER says otherwise), and the module chooser in Personnel's access controls if it hard-codes a list (*unverified*). Tolerant meanwhile. | before step 2 is visible to users |
| 1 | **EA** | Ship the enum value in EA with **no default change and no backfill** (inert): the value exists, nothing grants it, `GET /me` unchanged in shape. Add the contract fixture example in `fish-contracts` (additive) after GL's step 0 is live. | GL step 0 live |
| 2 | **EA + CM** | Turn on the defaults in section 3 (Owner Admin at registration and in `defaultModulesFor`; ACCOUNTANT at WRITE). **Backfill existing Owner Admin and ACCOUNTANT assignments only** (Femi, 2026-10-15); existing HR WRITE holders are **not** backfilled, and the switch-day report lists them so each Tenant is warned beforehand. Backfill only after step 1 has been stable (C3). | Femi's answers (given), CM release |
| 3 | **HR** | Build the enforcement and the `HR_ENFORCE_PAY_SPLIT` flag (default off), tests first; deploy off. | steps 0 to 2 live |
| 4 | **CM + Femi** | Turn the flag on per environment once the Owner Admin and chosen approvers hold PAYROLL. Because the Owner Admin keeps passing, this is a no-op for existing users. | Femi's go |

`GET /me` does not change shape at any step (only a new string value in an existing list), so the five strict mirrors need no field change; the only strict-decode exposure is GL's enum, closed by step 0.

## 8. What I did not verify

- Exact current WEB module chooser contents in Personnel's access controls; whether EA's invite route has any hard-coded module list beyond `ManagedModule.valueOf`.
- Whether one Membership can ever hold two assignments at the same Company (C2).
- HR's expense-claim and salary-advance gates beyond the Owner-only note in `OwnerCheck.kt` and the route list; the exact reason codes HR would add.
- Anything in production: which Companies currently have HR grants, how many non-Owner people hold HR WRITE at Companies that run payroll today (this is the number that decides Q2).

## 9. Decisions asked of Femi (all answered 2026-10-15)

1. **Default holders:** Owner Admin and ACCOUNTANT hold PAYROLL by default; HR_OFFICER does not. Agree? (Recommended: yes.) **Answered: yes; ACCOUNTANT at WRITE as proposed.**
2. **Backfill at the switch:** for existing people who hold HR today and can prepare a run, (a) give them PAYROLL too so nothing changes, then prune on request, or (b) give PAYROLL only to Owner Admins and accountants, so an HR officer loses the ability to prepare a run on the day the flag is on. (Recommended: (a) at step 2, so the flag flip stays a no-op; Femi prunes later. I can count the affected people from the Team data if CM can read it.) **Answered: only Owner Admins and Accountants; existing HR WRITE holders are not backfilled (option b), with a warning to each Tenant.**
3. **Pay basis and pay rate:** who may change an existing employee's pay basis, pay rate or frequency after the split? Today the Owner Admin only (rate, frequency, bank details). Recommended: unchanged, Owner Admin only, until Femi says an HR officer may propose and the Owner approves. **Answered: Owner Admin only, unchanged.**
4. **Access level for an approver:** accept constraint C1 (an approver's level applies to all modules in that Company's assignment) for Move 1? (Recommended: yes.) **Answered: accepted for now.**

The self-approval rule is **not** asked: it is already decided (Owner may approve their own run, recorded and flagged; a non-Owner may not, preparer is not approver).

## 10. The prepared switch (built inert 2026-10-17; NOTHING is enabled)

EA branch `feat/ea-payroll-enable-inert` (tests first; 519 unit tests and 11 persistence classes green). Everything below is dark until Femi announces the switch.

| Piece | What it is | How it stays inert |
|---|---|---|
| Accountant default | `Membership.defaultModulesFor(ACCOUNTANT)` includes PAYROLL (and, since 2026-10-18, IM; see section 3); the Owner Admin default already derived from the module list. | Both subtract `ManagedModule.withheld`; PAYROLL is still in it, so nobody gets it. |
| The enable step | Remove `PAYROLL` from `ManagedModule.withheld` (one line, its own release, after GL, SOP, POP, IM, HR and WEB have decoded the value). That one act turns on the defaults for new registrations and invites and un-refuses an explicit grant. | Not done. |
| Backfill | `BackfillPayrollModuleUseCase`: adds PAYROLL to existing Owner Admin and Accountant assignments (non-revoked), keeps role, level and other modules, idempotent, per-Tenant lock, dry run by default. Started at EA start-up by `EA_PAYROLL_BACKFILL=dry-run` or `execute` (unset = nothing). | Refuses (`NotEnabled`, logs "still withheld") while PAYROLL is withheld; env unset by default. |
| Switch-day warning | `GET /api/tenants/{tenantId}/payroll-switch-notice`, Owner Admin only: the switch date, who holds PAYROLL, and the people who can prepare a pay run today but will not (same rule as the switch-day SQL report, with names). WEB shows it as a "needs your attention" item. | 404 `not_scheduled` until `EA_PAYROLL_SWITCH_DATE` (yyyy-MM-dd) is set. |

**Switch-day order (CM runs, Femi announces):** (1) Femi runs the read-only SQL report for the counts. (2) CM sets `EA_PAYROLL_SWITCH_DATE`; Owner Admins see the warning; WEB shows it. (3) On the day: release with PAYROLL out of `withheld`; wait until stable (C3: no rollback once PAYROLL rows exist). (4) Run the backfill: first `EA_PAYROLL_BACKFILL=dry-run`, read the log counts (assignments it would change: one per Owner Admin and Accountant assignment that lacks PAYROLL), then `execute`, then unset it. (5) HR's enforcement flag later, per section 6. Nothing else EA does changes who can do what today.
