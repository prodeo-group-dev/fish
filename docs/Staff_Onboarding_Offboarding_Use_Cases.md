# Staff Onboarding and Offboarding — Use Cases

**Status:** DRAFT, 2026-10-06. SPUTO pass **U**. Requirements: `docs/Staff_Onboarding_Offboarding_SRS.md` (FR-ONB-n / NFR-ONB-n / OI-n). Backlog: `docs/Staff_Onboarding_Offboarding_Backlog.md`. Design only.

**Actors.** *Owner Admin* = the business owner (EA is his toolkit, not him). *Delegate* = an HR Officer, or anyone holding the HR module at WRITE or above at the Company. *HR*, *EA*, *ER* = the systems.

Error tokens below are HR's existing ones (`not_pending`, `not_owner`, `unauthorized`, `forbidden`, `ea_call_failed`) plus the proposed new ones, which are marked *(new)*.

---

## UC-ONB-1 Owner Admin onboards a person
- **Actor:** Owner Admin. **Preconditions:** the Company exists; the position code is in HR's vocabulary.
- **Main flow:** (1) Owner Admin opens HR and chooses Add a person; (2) enters name, email, position, employment type, start date, optional end date, pay terms; ticks whether the person needs to sign in; (3) submits; (4) HR records the request already APPROVED (requester and approver are both the Owner Admin) and applies it (UC-ONB-5); (5) the screen shows each step's result.
- **Alternate:** email already belongs to an active employee at this Company with an overlapping window: the request is refused with a clear message (a rehire after an end date is allowed, UC-ONB-9). Position not mapped for access: HR employs the person, access is reported "not set up: position has no access mapping" and no Membership is created.
- **Postconditions:** an Employee exists; if access was wanted, a pending invite exists and the invite email is sent.
- **Traces:** FR-ONB-1, 2, 5, 8, 10.

## UC-ONB-2 Delegate raises an onboarding
- **Actor:** Delegate. **Preconditions:** holds the HR module at WRITE+ at the Company.
- **Main flow:** (1)-(3) as UC-ONB-1; (4) HR stores the request as PENDING and tells the delegate "sent to the owner for approval"; (5) nothing is created yet; the Owner Admin sees it in the Approvals place (UC-ONB-4).
- **Alternate:** a caller without the HR grant gets `403 forbidden` with a reason.
- **Postconditions:** a PENDING request; no Employee, no Membership.
- **Traces:** FR-ONB-1, 2, 4, 13.

## UC-ONB-3 Delegate raises an offboarding
- **Actor:** Delegate (or Owner Admin, who is then self-approved as in UC-ONB-1). **Preconditions:** the employee exists and is not already ended.
- **Main flow:** (1) selects the person; (2) chooses Offboard, sets the last day (today or a future date) and an optional reason; (3) submits; (4) HR stores a PENDING request.
- **Alternate:** the person is the Owner Admin: refused (`409 cannot_offboard_owner` *(new)*). The person has no employee record but a hand-invited Membership: the request names the Membership (FR-ONB-11).
- **Postconditions:** a PENDING offboarding request; access unchanged until approved.
- **Traces:** FR-ONB-1, 2, 4, 11.

## UC-ONB-4 Owner Admin reviews what awaits approval
- **Actor:** Owner Admin. **Main flow:** (1) opens the one Approvals place in Administration; (2) sees onboarding, offboarding and payroll-run items together, each with who raised it and when; (3) opens one, which shows the HR detail screen with Approve and Reject.
- **Alternate:** one source is down (HR unreachable): the list shows the others and a line "HR approvals are not available right now" (the queue's `sourcesUnavailable`). A non-owner calling the queue gets `403 forbidden`.
- **Traces:** FR-ONB-13, 14, 15, 16.

## UC-ONB-5 Owner Admin approves, and the request is carried out
- **Actor:** Owner Admin. **Preconditions:** request is PENDING.
- **Main flow:** (1) presses Approve; (2) HR checks the caller is the tenant's Owner Admin through EA (`not_owner` otherwise) and that the status is still PENDING (`409 not_pending`); (3) HR marks it APPROVED and, for an onboarding, creates the Employee; for an offboarding, records the end date; (4) HR calls EA's internal employment route (PUT, or DELETE for an immediate end); (5) EA derives or ends the Membership and, for an Education Company, calls ER; (6) HR stores each leg's result and shows them.
- **Alternate:** EA or ER unreachable or failing: the request stays APPROVED with that leg "not synced"; the Owner Admin (or the delegate) presses Retry (UC-ONB-8). `ea_call_failed` is shown as "EA could not be reached; nothing was lost, try again".
- **Postconditions:** employment applied; access applied or pending retry; audit recorded.
- **Traces:** FR-ONB-3, 6, 7, 8, 9, 10.

## UC-ONB-6 Owner Admin rejects
- **Actor:** Owner Admin. **Main flow:** (1) presses Reject and gives a reason; (2) HR marks REJECTED with the reason; nothing is created or ended; (3) the delegate sees the decision and the reason.
- **Alternate:** `409 not_pending` if it was already decided or cancelled.
- **Traces:** FR-ONB-3, 6, 7, 17.

## UC-ONB-7 Delegate cancels their own pending request
- **Actor:** Delegate. **Main flow:** presses Cancel on their own PENDING request; HR marks it CANCELLED. A delegate cannot cancel another person's request (the Owner Admin can cancel any).
- **Alternate:** `409 not_pending` after a decision.
- **Traces:** FR-ONB-4, 6.

## UC-ONB-8 Retry a failed leg
- **Actor:** Owner Admin or the requesting delegate. **Main flow:** presses Retry on an APPROVED request with `complete = false`; HR repeats only the legs not complete, with the same `employmentId` and `version`, which EA and ER treat as idempotent (`UNCHANGED` counts as success). A newer change in between returns `STALE` (a success).
- **Alternate:** a leg refused as `409 version_conflict` or `409 existing_unlinked_assignment` shows the plain reason; the second needs an explicit decision (OI-9) and is never overwritten silently.
- **Traces:** FR-ONB-10.

## UC-ONB-9 Rehire and concurrent employments
- **Actor:** Owner Admin or Delegate. **Main flow:** a person who has left is onboarded again with the same email; HR creates a new Employee (new `employmentId`); EA and ER keep it as another employment link, and effective access is the union of the active windows, so the gap between the two employments is not access. Two concurrent employments (a salaried post and hourly cover) likewise.
- **Traces:** FR-ONB-12; teaching-staff drafts.

## UC-ONB-10 Owner Admin offboards with immediate effect
- **Actor:** Owner Admin. **Main flow:** raises an offboarding with the last day today; as in UC-ONB-1 it is self-approved; HR records the end date and calls EA's DELETE for that one employment, so that employment's access ends at once; the person loses access when no other employment of theirs at the Company remains active (at ER too: DELETE ends one link only).
- **Alternate:** a future last day: only `validUntil` is sent; access ends by the date rule with no scheduler.
- **Traces:** FR-ONB-9, 10.

## UC-ONB-11 Delegate sees their own requests
- **Actor:** Delegate. **Main flow:** HR screen "My requests" lists their requests with status, decision, reason and each leg's state. They never see Approve or Reject.
- **Traces:** FR-ONB-4, 17.

## UC-ONB-12 Someone without a grant tries to bring a person in
- **Actor:** any member without the HR grant, or a stranger. **Main flow:** the attempt is refused (`403 forbidden`, with the reason `no_membership`, `insufficient_access` or `module_not_granted` once HR ships it); EA's own invite and remove routes refuse everything except the Owner Admin (interim, OI-3) and later HR's approved execution.
- **Traces:** FR-ONB-18, 19.

## UC-ONB-13 Delegate proposes a pay change; the Owner Admin approves
- **Actor:** Delegate (raises), Owner Admin (approves). **Preconditions:** the employee exists and is not ended.
- **Main flow:** (1) the delegate opens the employee and chooses Change pay or bank details; (2) enters the new pay rate, pay frequency or bank details and a reason; (3) HR stores a `PAY_CHANGE` request as PENDING and the employee's pay stays as it was; (4) the Owner Admin sees it in the one Approvals place, with old and new pay figures (bank details shown only as "bank details changed"); (5) Approve applies it and writes the audit record; Reject keeps the old values and tells the delegate why.
- **Alternate:** the Owner Admin edits the pay fields directly, which is recorded as raised and approved in one step. A delegate who tries `PUT /employees/{id}` with a pay field gets `403 not_owner`.
- **Postconditions:** pay changes only after the Owner Admin's approval, always with an audit record of who and when.
- **Traces:** FR-ONB-3, 5, 21; D7, D8.
