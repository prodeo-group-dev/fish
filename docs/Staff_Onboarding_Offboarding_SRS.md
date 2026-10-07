# Staff Onboarding and Offboarding — Scope and Software Requirements Specification

**Status:** DRAFT for review, 2026-10-06. SPUTO pass **S** (scope) and **P** (plan), led by EA with HR, WEB and ER. Design only: nothing here is built, and nothing gets built until Femi says go. Companions: `docs/Staff_Onboarding_Offboarding_Use_Cases.md` (U) and `docs/Staff_Onboarding_Offboarding_Backlog.md` (T and O).

Vocabulary (Femi, 2026-10-06): **EA is the Owner Admin's toolkit; the Owner Admin is the business owner**, the person. EA is not the Owner Admin.

## 1. Scope

### 1.1 The problem
Bringing a person into a business, and taking them out, touches four systems, and today none of it is one process:

- **HR** holds the employment (an `Employee`), but there is no terminate action at all, no status, and creating an employee needs only WRITE access on the HR module, not the owner (`HR/.../EmployeeRoutes.kt`).
- **EA** holds access (a `Membership` with a role, access level and module grants). Its manual Team invite and remove can be done by an HR Officer with ADMIN access, with no approval (`EA/.../TenantRoutes.kt`, `authorizeStaffManagement`).
- **The Education Runtime (ER)** holds a school duty (a `StaffAssignment`) that is hand-typed and linked to neither of the above.
- Nothing records **who asked and who approved**. Payroll runs already have that shape (PENDING, APPROVED, REJECTED, owner-only approval); onboarding and offboarding do not.

### 1.2 Decisions already made (not re-opened here)
| # | Decision | Source |
|---|---|---|
| D1 | **Onboarding (which includes recruitment) and offboarding (termination) happen through HR.** There is no separate recruitment feature. | Femi, 2026-10-06 |
| D2 | **An HR Officer may be delegated the power to trigger an onboarding or offboarding; the final approval is the Owner Admin's, and only the Owner Admin's.** | Femi, 2026-10-06 |
| D3 | **Payroll runs are approved only by the Owner Admin. HR does payroll.** The payroll approval flow itself (preview, atomic claim, GL idempotency, retry) is **HR's own SPUTO**, `Payroll_Approval_*` on HR branch `docs/payroll-approval-sputo` (commit `ce81bd6`, FR-PA-1..14); this document references it and does not restate it. | Femi, 2026-10-06 |
| D4 | HR is the source of truth for employment; EA derives access from HR's position via a mapping EA owns; ER holds the school duty. | Teaching-staff drafts (HR, EA `be82609`/`eb5fe74`, ER) |
| D5 | HR and Payroll administration are grouped under EA (the Owner Admin's toolkit); WEB and EA collaborate on the screens. | Femi, 2026-10-06 |
| D6 | The EA dashboard is the Owner Admin's alone. | Femi, 2026-10-06 |
| D7 | **The Owner Admin is the sole approver.** Said after the peers' positions on pay changes ("You are all right... OWNER ADMIN be SOLE APPROVER"): nothing sensitive takes effect on a delegate's say-so alone, and no one but the Owner Admin approves. In particular a delegate's change to pay rate, pay frequency or bank details must not take effect without the Owner Admin (OI-12 settled in principle; the mechanism is in backlog row 0.10, including whether a delegate may also *propose* such a change from day one). | Femi, 2026-10-06 |
| D8 | **Delegates do the legwork; the Owner Admin takes the responsibility.** Said in answer to the pay-change question ("Delegates may have to do the legwork while the owner Admin will have to take responsibility"): a delegate may *propose* any sensitive change, including a change to pay rate, pay frequency or bank details; only the Owner Admin approves it and so owns it. This answers the propose question: pay changes are a request kind in v1 (FR-ONB-21), not Owner-only edits. | Femi, 2026-10-06 |
| D9 | **Adopt immediately: until the pay-change request exists, a delegate can neither make nor propose a change to pay rate, pay frequency or bank details.** Femi, quoting HR's stricter first version: "This should be adopted immediately". So the Owner-Admin-only rule on those three fields of `PUT /employees/{id}` (with its audit trail) is **not held back for the request flow**; it goes first (backlog row 1.6), and the `PAY_CHANGE` request kind (D8, FR-ONB-21) follows on the request machinery so delegates can then propose. | Femi, 2026-10-06 |

### 1.3 In scope
1. A **request** that an HR Officer or the Owner Admin raises to onboard or offboard a person, an approve or reject decision by the Owner Admin, and the execution that follows approval.
2. The execution chain after approval: HR employment, then EA access, then (Education Companies) the ER duty, with per-leg status and safe retry.
3. Where the Owner Admin sees what awaits approval, and what a delegate sees.
4. What happens to the existing direct paths (EA's manual Team invite and remove, HR's `POST /employees`, `PUT /employees/{id}` end dates) once requests exist.

### 1.4 Out of scope here
Recruitment as a candidate pipeline (adverts, applicants, interviews); pay, grading and contracts content; the payroll approval screen itself (HR's own SPUTO, but this SPUTO shares its Approvals place, see FR-ONB-14); leave, expenses and salary-advance approvals (already Owner-gated in HR); final-pay calculation on exit (flagged as OI-5).

### 1.5 Relationship to existing documents (what this supersedes)
- **Builds on, unchanged:** `docs/EA_Teaching_Staff_Onboarding_EA_Half_Draft.md` (FiSH master, tip `f3e0aa0`) and ER's and HR's halves: the access-derivation and school-duty legs, the employment-links model, the STAFF role plan, ER's pinned wire shapes.
- **Supersedes:** (a) the teaching-staff drafts' unstated assumption that an employment push follows directly from an HR action: it now follows an **approved request**, so approval sits in front of the HR -> EA -> ER chain; (b) EA's current rule that an HR Officer with ADMIN access can invite and remove staff with no approval (`authorizeStaffManagement`), and HR's `/team` proxy of it; (c) any reading of "only the Owner Admin can onboard" as excluding delegates: Femi's later answer is that delegates may trigger and the Owner Admin approves.
- **Defers to:** HR's `Payroll_Approval_*` SPUTO for everything about running and approving payroll; this document only shares its single Approvals place (FR-ONB-14) and its owner-only approval convention. Its FR-PA-11 (record, do not forbid, the Owner approving a run they submitted) matches FR-ONB-5 here.

## 2. Overall description

**Actors.** *Owner Admin* (the business owner, the one approver). *Delegate* (an HR Officer, or another person the Owner Admin lets raise requests). *Person* (the employee being onboarded or offboarded). *HR*, *EA* and *ER* as systems, calling each other only with service identities.

**Starting architecture (proposal, HR to confirm: OI-1).** A new HR aggregate, **`StaffChangeRequest`**, modelled on HR's existing `PayrollRunSubmission` rather than a second pattern: HR owns the employment, so HR owns the request; EA surfaces pending requests to the Owner Admin in its Approvals Queue and carries the access leg; ER carries the duty leg.

```
Delegate or Owner Admin raises request (HR)  ->  PENDING
Owner Admin approves (HR, owner-only)         ->  APPROVED  -> HR employment applied
                                                              -> EA internal route (access)
                                                              -> ER staff/employment (school duty)
Owner Admin rejects                           ->  REJECTED (reason recorded, nothing applied)
Requester cancels                             ->  CANCELLED
```

## 3. Functional requirements (MoSCoW)

### Requests and approval
- **FR-ONB-1 (Must)** A request has a kind (`ONBOARD` or `OFFBOARD`), the Company, the person's name and normalised email (trim + lowercase), the requester, a creation time, a status `PENDING | APPROVED | REJECTED | CANCELLED`, and, once decided, who decided, when, and a rejection reason.
- **FR-ONB-2 (Must)** An `ONBOARD` request carries what HR needs to create the employee (position code, employment type, start date, optional end date, pay terms as HR defines them) and whether the person needs system access. An `OFFBOARD` request names an existing employee and an end date (today or future); it can also carry a reason.
- **FR-ONB-3 (Must)** Only the tenant's Owner Admin can approve or reject. HR enforces it with its existing owner check (`requireOwnerCaller`, as `ApprovePayrollRunUseCase` already does) and EA does not trust HR's claim: EA's internal route accepts only HR's service identity and never creates or ends an Owner Admin Membership.
- **FR-ONB-4 (Must)** Who may **raise** a request: the Owner Admin, or a delegate. A delegate is a person whose Membership grants the HR module at WRITE or above at that Company (the existing HR grant, no new switch; OI-2 asks whether Femi wants an explicit delegation switch). A delegate can raise, see their own requests and cancel their own PENDING ones; a delegate can never approve or reject, including their own.
- **FR-ONB-5 (Must)** When the **Owner Admin raises** a request it is approved in the same step (one act, recorded as requester and approver both the Owner Admin), so the owner is never made to approve themselves.
- **FR-ONB-6 (Must)** A request can be decided only while PENDING (`409 not_pending`, the token HR already uses). Approve and reject are idempotent on retry of the same decision.
- **FR-ONB-7 (Must)** Everything is recorded: requester, approver, times, rejection reason. This is an audit trail, kept for the life of the employment record.

### Execution after approval
- **FR-ONB-8 (Must)** On approval of an onboarding, HR creates the `Employee` (email required and normalised; OI-4 on unpaid staff), then calls EA's internal route for HR's service identity (`PUT /api/internal/tenants/{tenantId}/employments/{employmentId}`, contract in `docs/EA_Teaching_Staff_Onboarding_EA_Half_Draft.md`), which derives the Membership and, for Education Companies, calls ER.
- **FR-ONB-9 (Must)** On approval of an offboarding, HR records the end date (access ends when **no other employment of that person at the Company remains active**). A future end date is a `validUntil` and takes effect with no scheduler (EA's union-of-active-windows rule, ER's own window). An end date of today also calls `DELETE` on the same EA route for an immediate cut-off.
- **FR-ONB-10 (Must)** Each leg's outcome is stored and shown (`employment`, `membership`, `school duty`, and an overall `complete`). A failed leg does not undo an earlier one; the same request is retried with the same `employmentId` and `version`, which every leg already treats as idempotent. No queue or outbox in EA (already agreed).
- **FR-ONB-11 (Must)** Offboarding must be able to revoke access **without** an HR employee, for a Membership that exists with no employment link (the old hand-invited staff). This is a **third request kind, `OFFBOARD_MEMBERSHIP`** (HR's half): HR stores the request, and execution calls EA's existing revoke **with the approving Owner Admin's own bearer token**, because HR has no Membership concept and EA is the one that can check the Membership belongs to the Company. Retries therefore need the Owner Admin present, which is acceptable since only the Owner Admin can retry. The Owner Admin Membership can never be offboarded this way.
- **FR-ONB-12 (Should)** Rehire is a new request and a new HR Employee with the same email, which EA and ER already treat as another employment link (no conflict).

### Where it is seen
- **FR-ONB-13 (Must)** EA's Approvals Queue gains two item sources, `HR_ONBOARDING_REQUEST` and `HR_OFFBOARDING_REQUEST`, listing PENDING requests with the person, kind, requester and date, alongside the existing `HR_PAYROLL_RUN` source. A failed source goes into `sourcesUnavailable` as the queue already does.
- **FR-ONB-14 (Must)** One place for approvals: the Owner Admin sees onboarding, offboarding and payroll-run approvals in a single list, each opening the HR screen that holds the detail and the Approve and Reject actions. (WEB asked for payroll approval to live in one place, not two; this extends the same principle.)
- **FR-ONB-15 (Must)** The Approvals Queue is the Owner Admin's. Today it can be read by any member with READ at the Company, which would show every pending payroll run and staff change to anyone with a grant; it is restricted to the Owner Admin as the dashboard now is (a finding, see OI-6).
- **FR-ONB-16 (Should)** The Owner Admin is told when something awaits approval (one line through EA's communication centre, or on the dashboard header; OI-7).
- **FR-ONB-17 (Should)** A delegate sees the status of their own requests, including a rejection reason.

### The existing direct paths
- **FR-ONB-18 (Must)** Once requests exist, a person cannot be brought in or taken out of a business by a route that skips approval. The direct paths to close are wider than `POST /employees` (HR's finding): `POST /employees` **and any end-date change through `PUT /employees/{id}`** become Owner-only direct acts (equivalent to an Owner-raised request, FR-ONB-5) with delegates using the request route; EA's staff invite and remove, and HR's `POST /team` and `DELETE /team/{id}` proxies (which have no HR-side owner check today), are used only as the execution step of an approved request, or by the Owner Admin. HR will not touch the `/team` proxies before Femi settles OI-3.
- **FR-ONB-19 (Must, interim, **pending Femi's confirmation of OI-3**; it revises his 2026-09-23 direction and is not built until he says so)** Until requests ship, the stricter reading is recommended (OI-3): EA's invite and remove become Owner-Admin only, so the gap that approval exists to close is not left open meanwhile. Listing the roster stays available to delegates.
- **FR-ONB-20 (Should)** HR gets a real terminate path (today there is only an `endDate` set through `PUT /employees/{id}` and no status), so "who is currently employed" is a query, not an inference.
- **FR-ONB-21 (Must)** A fourth request kind, **`PAY_CHANGE`** (D8): a delegate raises a change to an existing employee's pay rate, pay frequency or bank details; it is PENDING until the Owner Admin approves, then HR applies it and records it. Until then the employee's pay is unchanged. The three fields on `PUT /employees/{id}` become Owner-Admin-only direct acts (an Owner Admin editing them directly is the same as raising and approving in one step, FR-ONB-5); delegates keep name, email and hours. Each applied change is written to an audit trail: old and new values for pay rate and pay frequency; for bank details only that the field changed and by whom, never the values (they stay encrypted).

## 4. Non-functional requirements
- **NFR-ONB-1 Security.** Approval is authorization-path code: the approver identity comes from EA's membership, never from a request body; HR re-checks the owner on every decision; the internal EA route accepts only HR's service audience and fails closed when it is unset; the person's email is verified at sign-in, never trusted from a push alone. HIGH review (CM) on each leg that changes who can do what.
- **NFR-ONB-2 Strict decoding.** Every hand-mirrored DTO between the services declares each new field, and `ignoreUnknownKeys` is not used on these payloads (platform rule, 2026-09-29).
- **NFR-ONB-3 Idempotency.** Every command repeats safely; ordering is by `version`, a lower version is `STALE` and not an error.
- **NFR-ONB-4 Multi-tenancy.** The Company must belong to the tenant on every call; an HR deployment is single-tenant but EA still checks.
- **NFR-ONB-5 No pay data crosses to EA or ER.** Only email, name, position, dates and the Company.
- **NFR-ONB-6 UX.** One approvals place; every state and every failed leg is explained in plain words with a way to retry; written for a non-accountant owner on a phone.
- **NFR-ONB-7 Release discipline.** Consumers ship before producers for any new enum value or field; CM pushes and deploys; each auth change is its own deploy.

## 5. Data requirements
- `StaffChangeRequest` (HR): id, companyId, kind, status, personName, email, positionCode?, employmentType?, startDate?, endDate?, membershipId? (for FR-ONB-11), requestedBy, requestedAt, decidedBy?, decidedAt?, rejectionReason?, employmentId?, per-leg outcomes, version.
- HR `Employee` gains a required normalised email on this path (it is optional today).
- **Decision and execution are separate (HR's refinement):** `status` is the decision (`PENDING | APPROVED | REJECTED | CANCELLED`); `execution` is how far applying it has got (`NOT_STARTED | IN_PROGRESS | COMPLETE | PARTIAL`) with per-leg outcomes for `EMPLOYMENT`, `ACCESS` and `SCHOOL_DUTY`, so APPROVED is never read as access granted. Execution reuses the atomic claim from HR's payroll SPUTO, so two retry clicks cannot run a request twice. HR stores no Employee status; `UPCOMING | ACTIVE | ENDED` is derived from dates.
- **Version is a monotonic integer per employment** (incremented on every change that is pushed), not an instant, because a wall-clock instant can tie or go backwards across ECS tasks and a newer push would read as `STALE`. `employmentId` is the HR Employee id; a rehire is a new Employee and so a new `employmentId`.
- **Position codes** are owned by HR as one small global closed list in v1: `STAFF`, `TEACHER`, `NON_TEACHING_STAFF`. ER's own duties (HOD, HOY, HEAD_TEACHER, REGISTRAR, BURSAR) stay admin-assigned and never come from HR. HR validates only that the code is in the list; EA owns the mapping from a code to a role, access and ER duty, and refuses an unmapped code (`422 position_not_mapped`). The mapping's content (for example `TEACHER` to role `STAFF` plus the Education module at READ plus ER duty `TEACHER`; `NON_TEACHING_STAFF` and `STAFF` to role `STAFF` with no ER duty) is a business decision for Femi, with OI-8.
- HR's own half, with the exact request JSON and error tokens for WEB, is `docs/Staff_Change_Request_HR_Half.md` (HR branch `docs/hr-staff-change-request-half`, `409b70a`); it is the wire contract for backlog rows 2.2 to 2.4 and is not restated here.
- EA: `employment_links` and an `EMPLOYMENT` assignment source, as in the teaching-staff draft; no new field on `GET /me`.

## 6. External interfaces
| From -> to | Interface | Notes |
|---|---|---|
| WEB -> HR | requests: raise, list, get, cancel, approve, reject | owner-only for the last two |
| WEB -> EA | Approvals Queue (adds the two sources), `GET /me` | queue becomes Owner-Admin only |
| HR -> EA | `PUT`/`DELETE /api/internal/tenants/{t}/employments/{id}` | HR service identity only; EA_JWT_SERVICE_AUDIENCE_HR is set in production (CM, 2026-10-06) |
| EA -> ER | `PUT`/`DELETE /schools/{schoolId}/staff/{email}/employment[/{employmentId}]` | `ea-provisioning`, TEACHER only in v1 |
| EA -> HR | list pending requests for the queue | read-only, caller's bearer forwarded as for payroll runs |

## 7. Open issues (each needs an owner and, where marked, Femi)
- **OI-1 (HR)** Request lives in HR (recommended: HR owns the employment, the request follows the payroll-run pattern) or in EA? Affects who stores the audit trail.
- **OI-2 (Femi)** Is "delegated" simply holding the HR module at WRITE at that Company (recommended, no new concept), or an explicit switch the Owner Admin turns on for a named person?
- **OI-3 (Femi)** Interim: tighten EA's invite and remove to Owner-Admin only until requests ship (EA's recommendation)? **This is not a decision yet, and it would revise one.** On 2026-09-23 Femi directed that staff management stay available to an HR Officer at ADMIN level ("if the owner admin has HR being managed for him", recorded in EA's `Auth.kt`). His 2026-10-06 rule (an HR Officer may trigger, the Owner Admin gives final approval) keeps the delegate's power to **trigger** but removes the power to act **without approval**; the interim restriction only closes that gap until the request flow exists. Until Femi confirms it, EA's invite and remove stay as they are, so nothing here is a regression by default.
- **OI-4 (Femi)** Unpaid staff (volunteers, governors, trustees): HR rejects a non-positive pay rate today. **HR's proposal:** one new employment type `UNPAID`, a zero pay rate allowed for that type only, excluded from payroll lines, with position, email, dates and the full onboarding and offboarding flow; smaller than a Person or Staff supertype. Cost: `employmentType` gains a value, so WEB and any strict decoder must accept it first (consumers before producer). HR has no stronger view than "do it this way unless Femi wants the supertype".
- **OI-5 (Femi to confirm)** Final pay on exit. **HR's position, adopted here:** an offboarding does not trigger payroll in v1. It records the end date and shows the Owner Admin the consequences (pending payroll runs, outstanding salary advances, other active employments) through `GET /employees/{id}/offboarding-preview`; warn, never block. Final pay is a normal payroll run the Owner Admin approves; a run line for an employee whose end date is before the period start is refused (`employee_ended`), and the period containing the end date is valid. An outstanding salary advance stays outstanding; leave payout is out of scope until Femi asks.
- **OI-6 (EA, CM)** The Approvals Queue's company READ gate is wider than its content warrants (finding; fix is small and ships behind WEB's role-based visibility).
- **OI-7 (WEB)** How the Owner Admin is told something awaits approval.
- **OI-8 (Femi)** Which EA role a teacher or other non-function staff member holds: a generic `STAFF` role (EA's recommendation, GL first and EA last in the release order, agreed with CM).
- **OI-10 (CM, Femi)** Personal data in these records (names, emails, reasons for termination, any recruitment detail): how long they are kept, who can read the audit trail, and whether a terminated person's data is later removed or only archived. Femi's full security scope waits for the live switch, but the questions are recorded now rather than later.
- **OI-9 (decided, Femi 2026-10-07, as reported by the Education Runtime session: "Adopt it, but only with explicit owner confirmation")** A hand-entered Education Runtime assignment is **refused by default** (409 `existing_unlinked_assignment`, nothing changes). Adoption happens only through `adoptExisting: true` on the same PUT (answered `APPLIED_ADOPTED`), and EA sends that flag **only after the Owner Admin has explicitly confirmed adopting that specific person**, having been shown that HR's dates will then gate all of that person's duties at the school, including any hand-granted ones. Proposed refinement (Education Runtime, with HR and EA to confirm): the call also carries `adoptionConfirmedBy` (the Owner Admin's email), which the Education Runtime stores with the time on the link for audit. **EA adds a check Education Runtime cannot make:** EA accepts the flag only when `adoptionConfirmedBy` equals the email of the tenant's Owner Admin, else it refuses (`422 adoption_not_confirmed_by_owner`) and sends nothing. The flow: HR's onboarding leg fails with `existing_unlinked_assignment`; the Owner Admin sees the warning in HR and confirms; HR retries the same employment with the confirmation, and EA's internal route accepts two new optional fields (`adoptExisting`, `adoptionConfirmedBy`, declared in EA first).
- **OI-11 (Femi, ER)** Dormant admin-granted ER roles on rehire: after every employment link ends, hand-granted ER roles stay on the row and revive when a rehire creates a new active link. ER's lean: an explicit DELETE of the last active link also clears admin-granted roles. Undecided.
- **OI-12 (settled by D7 and D8)** A delegate with WRITE on HR could change an employee's pay rate through `PUT /employees/{id}`, which the original rule did not cover. Resolved: those three fields become Owner-Admin-only direct acts and a delegate proposes through a `PAY_CHANGE` request (FR-ONB-21). Recorded for the history; HR designs the request kind.
