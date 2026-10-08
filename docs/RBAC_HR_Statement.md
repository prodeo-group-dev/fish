# RBAC: HR / Payroll statement for the application round

**Owner:** HR session. **Status:** statement of current rules and plan, docs only, 2026-10-08. **Written against:** HR `origin/master` including payroll approval Wave 3 (live as HR task definition :32), read in the working tree on 2026-10-08. Every claim below was read from that code; nothing here changes code or an authorization rule (the freeze holds). Items I did not run against production are marked **[not run]**.

---

## 1. HR's current authorization rules, as the code does them

| Topic | What HR does today | Where |
|---|---|---|
| Identity | One human verifier: JWT RS256 against the shared JWKS. `HR_JWT_ISSUER`, `HR_JWT_AUDIENCE` and `HR_JWT_JWKS_URL` are read at start-up and HR **refuses to start** if any is unset. Only the `email` claim is used (`VerifiedIdentity(email)`); no `sub`, no canonicalisation. HR has **no inbound service-account provider**: it authenticates people only, so there is no `?: verifier` fall-back to remove. | `Auth.kt` `installHrJwtAuth`, `buildJwksVerifier` |
| Per-Company decision | `HrMembershipAuthorizer.resolve`: EA `GET /me` with the caller's own bearer token; take the Membership whose Tenant is this deployment's (`HR_EA_TENANT_ID`); require `accessLevelAt(companyId)` at least the route's minimum **and** `"HR"` in `grantedModulesAt(companyId)`. `accessLevelAt` is NONE for a Company absent from `/me`, and for a present Company with a null level it is READ for the Owner Admin and NONE for anyone else; the module check then runs for everyone, so a null level with no HR grant is refused anyway. EA unreachable answers **503** (fail closed); a bad token **401**. | `Auth.kt`, `ea_membership_gateway.kt` |
| Refusal shape | `403 forbidden` with a machine-readable `reason` (`NO_MEMBERSHIP`, `INSUFFICIENT_ACCESS`, `MODULE_NOT_GRANTED`). **By-id routes answer 404** for a Company the caller cannot see, so existence is not leaked. | `Auth.kt` |
| READ (level READ + HR) | `GET` employees (list, by id), leave requests and balance, expense claims, salary advances, expense-claim policy, `GET /payroll/last-run`, payroll submissions (list, by id) and the advisory preview. | `*Routes.kt` |
| WRITE (level WRITE + HR) | `POST /employees` (**including the initial pay rate, pay frequency and bank details**), `PUT /employees/{id}` for the non-guarded fields, submit a leave request, submit an expense claim, request a salary advance, **submit a payroll run** (`POST /payroll/run`). | `EmployeeRoutes.kt`, `LeaveRequestRoutes.kt`, `ExpenseClaimRoutes.kt`, `SalaryAdvanceRoutes.kt`, `PayrollRoutes.kt` |
| APPROVE (level APPROVE + HR) | **Only** leave approve and reject. This is the one place HR uses the APPROVE level. | `LeaveRequestRoutes.kt` |
| Owner-only | `requireOwnerCaller`: HR lists the Tenant's memberships from EA with the caller's token, finds the caller **by exact email match**, and requires `isOwnerAdmin`. Used for payroll **approve, reject and retry**, expense-claim approve and reject, salary-advance approve and reject, setting the expense-claim policy, and any `PUT /employees/{id}` that changes pay rate, pay frequency or bank details (`403 not_owner` for anyone else; each such change is recorded in the employee change audit with the actor's email). **These routes skip `authorizeHr` entirely**: no level, no module and no Company check, only "is the Tenant's Owner Admin". | `OwnerCheck.kt`, `ApprovePayrollRunUseCase`, `RetryPayrollPostingsUseCase`, `Approve/Reject{ExpenseClaim,SalaryAdvance}UseCase`, `SetExpenseClaimPolicyUseCase`, `EmployeeRoutes.kt` |
| No HR gate at all (EA decides) | `/team` (invite, list, remove) and `GET/PUT /companies/{id}/employees/module-responsibilities` forward the caller's bearer token to EA and return EA's answer. HR adds no check of its own. | `TeamRoutes.kt`, `StaffResponsibilityRoutes.kt` |
| Bank details | Returned (decrypted) **only when `/me` says the caller is the Owner Admin**; everyone else with READ gets `bankDetailsOnFile` (a boolean). A delegate's `PUT` that omits or nulls `bankDetails` keeps the stored value; a different value is a guarded change (403). | `RouteHelpers.kt`, `EmployeeRoutes.kt` |
| Pay data | **Not hidden.** Pay rate and frequency are on every employee response, and the payroll submission, the preview and the approve response carry per-line gross, deductions and net, for **any caller with READ** at the Company. | `RouteHelpers.kt`, `Dtos.kt` |
| Approver identity | Taken from the token, never from a body field. Payroll records `submittedBy` and `decidedBy` (both emails) on the submission. **Leave, expense-claim and salary-advance records store no creator and no approver at all**, only a decision date. | `PayrollRoutes.kt`, `payroll_run_submission.kt`, `leave_request.kt`, `expense_claim.kt`, `salary_advance.kt` |
| Outbound | HR calls GL as itself with a Cognito service account and sends an `Idempotency-Key` on payroll postings. The `X-Tenant-Id` it sends is one deploy-time value (`HR_GL_ENGINE_TENANT_ID`). HR also fixes its own EA Tenant per deployment (`HR_EA_TENANT_ID`). | `ktor_gl_engine_gateway.kt`, `Application.kt` |

---

## 2. Survey items that name HR, re-verified

**2.1 `submittedBy` and `decidedBy` can be the same person. True, and it is by construction today.** Any WRITE caller can submit a payroll run, and only the Owner Admin can approve it, so the two are equal exactly when the Owner submitted the run himself. Both are recorded; nothing forbids it and nothing flags it (the flag is derivable by comparing the two). That matches D6 for the Owner. What is missing is the rule for the day approval is delegated (D2): then a non-Owner approver could approve a run he submitted, and HR has no check. Expense claims and salary advances are worse: they record no creator, so neither "flag it" nor "forbid it" is possible yet.

**2.2 `POST /employees` lets a WRITE delegate set initial pay and bank details. True.** `POST /employees` is gated by `authorizeHrForWrite` only and accepts the pay rate, frequency and bank details. Changes after creation are owner-only and audited (row 1.6, live), but the first value is not. This is real and is the T10 item.

**2.3 The owner match is exact-case. True.** `requireOwnerCaller` compares `it.email == callerEmail`, and `GetStaffModuleResponsibilitiesUseCase` joins the roster with `associateBy { it.email }`. The failure mode is **fail closed** (a differently cased token email is "not the owner"), so it is an annoyance and a support risk, not an escalation path.

**2.4 F7, approve routes skip the module check. True.** The Owner-only routes in section 1 do not call `authorizeHr`. Today that is harmless (one Tenant per deployment, the Owner owns every Company, and EA now gives the Owner an explicit HR assignment at each registered Company), but it is the reason delegation (D2) cannot be added by changing a flag: the capability check would have to be added to those routes.

**2.5 F1 (fail-open verifiers). Not present in HR.** There is one human verifier and no service provider, and a missing audience variable stops start-up. T1 needs no work in HR.

**2.6 The Owner is not at a bare READ floor in HR.** The `accessLevel ?: READ` fall-back for the Owner is real in code but moot: EA's registration now creates the Owner an explicit `ADMIN` assignment with `HR` among its modules at each registered Company, and HR's module check refuses anyone with no HR grant, Owner included. Companies registered before that change **[not run]** are the T23 production check.

---

## 3. Gaps against R1-R13 and tasks T2, T4, T10

| Requirement or task | HR today | Gap | Estimate and order |
|---|---|---|---|
| R1 capabilities | Uses READ, WRITE and (leave only) APPROVE; ADMIN never used | Nothing until T5a lands. HR then maps its routes to *read*, *view-financial*, *write*, *approve*, *administer* | Mapping and re-gating ~2 days, **after T5a** |
| R2 approvals | Owner-only email match for money approvals; token-derived approver; leave uses APPROVE | Approvers other than the Owner cannot exist; no creator != approver rule; no `selfApproved` flag; leave, expense, advance record no actor | See T10, T22 below |
| R3 thresholds and policy | Expense-claim policy is Owner-only (stricter than *administer*) | None needed; map to *administer* (the Owner always holds it) when T5a lands | ~0.5 day with R1 |
| R4 Owner explicit assignments | HR applies **no local uplift**, except that `/me`'s `isOwnerAdmin` reveals bank details and gates owner-only routes | None; HR needs only T6 to have run | 0 |
| R5 delegation | HR proxies `/team` and module-responsibilities to EA unchecked | None in HR (EA's T14); HR must keep forwarding the caller's token | 0 |
| R6 fail closed | Already true (single verifier, start-up refusal) | None | 0 (T1 not applicable) |
| R7 service credentials | Outbound only; Tenant fixed per deployment for both GL and EA | The deploy-time Tenant values go when T15 lands (derive from the Company) | ~1 day after T15 |
| R8 missing Company = NONE | Already NONE for everyone including the Owner | **None. T4 is already true in HR** | 0 |
| R9 / **T2** canonical email | Exact-case match in `requireOwnerCaller`; roster join in the responsibilities use case; the token email is stored as given in `submittedBy`, `decidedBy` and the audit actor | Canonicalise at `VerifiedIdentity` (trim, lower-case); see 4.2 for the better fix for the owner check | ~0.5 day for canonicalisation; ~1 day if the owner check also moves to `/me` (4.2); HIGH review (auth) |
| R10 / **T22** audit | Employee change audit (actor email) for pay and bank; payroll `submittedBy`/`decidedBy` | Leave, expense, advance: no creator, no approver, no user id | Additive columns (`created_by`, `decided_by`, user id from `/me`) in one migration, ~1 day, **a prerequisite for any creator != approver rule** |
| R11 WEB | n/a to HR code | WEB hides approve controls by `isOwnerAdmin`; HR's contract is unchanged | WEB's T16 |
| R12 runtime contract | n/a | The ER teaching-staff onboarding goes through HR and needs the Owner-confirmed adoption flag (decided 2026-10-07) | With the staff change request build, not RBAC |
| R13 operators | n/a | None | 0 |
| **T10a** `submittedBy` != `decidedBy` (Owner exception), flagged self-approval | By construction equal only for the Owner; no check, no flag | Add the compare to approve and reject for non-Owner approvers; write `selfApproved` (derivable today) with the audit record | ~1 day. **After T5a/D2 and T22** (expense and advance need the creator recorded first) |
| **T10b** initial pay and bank details on create are owner/administer-only | `POST /employees` open to WRITE | See 4.1: cannot ship alone | Blocked on the staff change request flow (HR rows 2.1-2.4) |
| T4 | Already NONE | None | 0 |

**How "the Owner holds the approver role explicitly" (D2/D4) maps onto `requireOwnerCaller`.** Today the Owner's approval power is *implicit in a flag* (`isOwnerAdmin`) and is checked by a roster email match. Under D2 it becomes *explicit in the data*: the Owner holds the *approve* capability at each Company as an assignment, and so can anyone he delegates it to. In HR that means replacing `requireOwnerCaller` on the money-approval routes (payroll approve/reject/retry, expense, advance) with "holds *approve* at the record's own Company and the HR module" (using the same `/me` call the other gates use), plus the creator != approver rule for non-Owners and the Owner's self-approval allowed and flagged. The Owner passes the new check because EA gives him the assignment and he cannot remove it (T6). Two things stay Owner-only rather than becoming capabilities: changing pay rate, frequency or bank details (Femi's "A now, B later"), and, until D7/R3 say otherwise, setting the expense policy (*administer*).

---

## 4. Objections and things the SPUTO missed

**4.1 T10b conflicts with delegates doing the legwork, and with pay integrity.** Femi's standing direction is that delegates do the legwork and the Owner takes responsibility ("A now, B later"). A paid employee cannot be created without a pay rate (pay integrity: a SALARIED or HOURLY employee with no pay cannot be stored). So if `POST /employees` becomes owner-only for pay and bank details, a delegate can no longer hire anyone paid, which breaks the very flow the Owner wants delegates for. T10b is only safe **after** the staff change request flow (HR rows 2.1-2.4: the delegate proposes, the Owner approves with the pay), or as an interim rule that a delegate may create only UNPAID employees. I recommend sequencing T10b behind that flow and not enforcing it earlier.

**4.2 The owner check can drop the roster call and the email compare.** `requireOwnerCaller` lists the whole Tenant roster with the caller's token and matches by email. HR already reads `isOwnerAdmin` for the caller from `/me` (it uses it to reveal bank details). Using that one signal for the owner check removes the exact-case compare (the T2 problem for HR), one roster call per approve, and a failure path (a non-Owner who cannot list the roster gets a confusing `forbidden`). I would do T2 for HR as "`/me`'s `isOwnerAdmin`, plus canonicalise the stored emails", not as a case-insensitive roster match. I need EA to confirm that `/me`'s `isOwnerAdmin` is the authoritative owner flag and will stay.

**4.3 D9 (view-financial) reaches HR: pay is financial data.** Today any READ caller sees every employee's pay rate and frequency, and the payroll submission, the preview and the approve response show per-line gross, deductions and net. The preview and the submissions are not new exposure (they follow the existing READ rule), but they make the question concrete. I propose: employee name, position, dates and leave need only *read*; pay rate and frequency, payroll submissions, the preview and payslips need *view-financial*. WEB would then hide the pay column from a read-only user. This needs D9 settled with Femi and WEB's T16, and is a response-shape change (fields absent or null for a reader), so it is consumers-first.

**4.4 Approve routes ignore the Company.** The Owner-only routes do not check that the record's Company is one the caller may act on. Harmless today (one Tenant, the Owner holds every Company), but once approval is delegated per Company (R2) the new check must be per record Company. I flag it now so it is built in and not retrofitted.

**4.5 Concurrency and approval are now linked.** The payroll approve is a claim with a lease (live), so a delegated approver and the Owner approving at the same moment is already safe: one claim wins. No RBAC change is needed there; noting it so the SPUTO does not plan a second guard.

**4.6 `selfApproved` should be a stored fact, not derived on read.** Comparing `submittedBy` and `decidedBy` works only while both are canonical emails (T2). Write it at decision time.

---

## 5. What HR needs from others

- **EA:** (a) confirm `/me`'s `isOwnerAdmin` is the authoritative owner signal (4.2); (b) the stable user id in `/me` for T22; (c) the `capabilities` field and the rollout dates for T5a so HR can declare it first (strict decoding); (d) T6 and the T23 production check done before HR relies on the Owner's explicit HR assignment everywhere. HR's treatment of `accessLevel: null` today: Owner READ, anyone else NONE, then the module check refuses everyone without an HR grant.
- **WEB:** D9 handling for pay (4.3), approve controls by capability from `/me` (T16), and the `selfApproved` display once the field exists.
- **CM:** a decision on 4.2 (drop the roster call), and where T22's shared audit shape lands so HR's migration matches it.
- **Femi:** D9 (is pay financial data?) and confirmation of the 4.1 sequencing (T10b behind the staff change request flow).

---

## 6. HR's plan and order (nothing is built, the freeze holds)

1. **Now, no policy change:** none required by T1 or T4 (already true in HR).
2. **On CM's go (add-a-deny or equivalent):** T2 for HR as in 4.2, and the additive T22 columns for leave, expense and advance.
3. **After T5a and D2:** re-gate the money approvals on the *approve* capability at the record's Company, with creator != approver for non-Owners and the stored `selfApproved` flag (T10a); map READ/WRITE routes to the capability set; view-financial per D9.
4. **After the staff change request flow:** T10b.
5. **After T15:** drop the deploy-time Tenant values.

Branches: none yet. Each step above will be its own branch from `origin/master` in the HR checkout, handed to CM as branch and tip.

*Sources: HR code read 2026-10-08; `docs/RBAC_SPUTO.md` v0.3; `docs/RBAC_EA_Statement.md`; `HR/docs/Payroll_Approval_Software_Requirements_Specification.md`; `HR/docs/Staff_Change_Request_HR_Half.md`.*
