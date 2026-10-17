PERSONNEL PLAYBOOK (draft for Omniview's Playbooks tab, area Personnel; also the Business Owner's acceptance list for the Personnel approval screens)

Written by the EA session, 2026-10-17 (Femi: "SPUTOs create playbooks"). Written from EA master 82858d0 and HR master 95199c2 (the Team routes and employee routes are live; the request flow is NOT built). Personnel is the area formerly called People and, before that, Team. Where this sheet says NOT BUILT, believe it over any older document.

PLAYBOOK CONTENTS (see docs/Playbook_Definition.md)
1. Operator sheet: this document, sections A to G.
2. Scope: docs/Personnel_Scope_SPUTO.md section 1.
3. Plan / SRS: docs/Personnel_Scope_SPUTO.md section 4 (FR-PEO-01 to 19, NFR-PEO-01 to 07); staff onboarding and offboarding: docs/Staff_Onboarding_Offboarding_SRS.md.
4. Use cases: docs/Personnel_Scope_SPUTO.md section 6 (UC-PEO-01 to 14, UC-ACC-01 to 03) and its "Phone check"; docs/Staff_Onboarding_Offboarding_Use_Cases.md.
5. Tasks: docs/Personnel_Scope_SPUTO.md section 7; docs/Staff_Onboarding_Offboarding_Backlog.md; HR's half: HR repo docs/Staff_Change_Request_HR_Half.md.
6. Order: docs/Personnel_Scope_SPUTO.md section 7 "Critical path"; the live-switch gate is docs/Live_Switch_Checklist.md (P8).
Also: docs/HR_Payroll_Seam_Note.md (what stays in Personnel when Payroll leaves) and docs/Payroll_Playbook.md.

A. DECIDED (Femi; Decisions_Log). Do not re-ask.
- The area is called PERSONNEL, under Administration. Not "People", not "Team". There is no separate Access screen and no "Access" label.
- Invite, roles, modules and remove-access stay in HR/Personnel. EA stays the system of record and the authority: HR forwards the person's own token and EA re-authorises every call.
- Each employee row gets "Give access" / "Remove access" (and a way to change role or modules). One extra button, "Invite someone who isn't an employee", covers a person such as the outside accountant.
- Final authority over hiring and firing is the Business Owner. Intended end state, REQUIRED BEFORE THE LIVE SWITCH (P8): anyone other than the Owner Admin RAISES an access change (give, change, remove) or a hire/leaver request, only the Owner Admin approves, then EA executes; the Owner Admin acting directly is approved in the same step and recorded self-approved. Built on HR's StaffChangeRequest machinery (HR owns the request kinds).
- Until that flow exists delegates keep acting directly as today (P7): no interim refusal.
- Pay is not Personnel's: pay basis stays here; pay rate, frequency and bank details are Payroll's and Owner-Admin-only.
- Still open (Femi has not decided; research assigned): P3 depth for an SME, P4 jurisdictions first, P5 configurable leave policy, P6 employee self-service (blocked on the STAFF role decision).
- Prodeo is a landlord: it has no role in a Tenant's staff, access or employment records. FiSH prepares; the Tenant owns what it records.

B. WHAT THE SYSTEM DOES TODAY
- Employees (HR): name, email (canonical, unique), bank details, employment type (salaried, hourly, unpaid), pay rate and frequency, working days and hours, start and end date. Changes are audited. There is NO job title/position, division, line manager, phone, address, emergency contact, right-to-work record, contract record or document store.
- Leave (HR): annual and sick leave, request, approve/reject, balances. The policy is hard-coded for every Company: annual leave accrues 1.75 days a month, sick leave is 10 days a year.
- Access (HR proxies to EA): POST /team (invite), GET /team (roster), DELETE /team/{membershipId} (remove), plus module-responsibility edits. An invite is a pending membership until the person accepts with their own sign-in (it can expire or already be answered). Removing twice gives 409 already_revoked. The Owner Admin can never be removed and never created by an invite.
- Who may do it today: the Owner Admin directly, and an HR Officer holding ADMIN at the Company (EA's canManageStaffAt) directly, with NO Owner approval. That is deliberately accepted for now (P7).
- A request for the PAYROLL module is refused with 422 module_not_yet_available (not grantable until the switch). Education Runtime is only for schools.
- WEB shows this screen under the name People/Team until its rename lands.

C. COMMON QUESTIONS AND HOW TO ANSWER
Q: "How do I give a new employee access to the system?"
A: In Personnel, on their row, choose "Give access" (choose role, level and modules per Company). If they are not an employee (an outside accountant), use "Invite someone who isn't an employee". Today the Owner Admin acts directly. The "give access" wording is the target; until WEB's rename lands the screen may still say Team.
Q: "Can my HR officer add or remove people without me?"
A: Today yes, if they hold ADMIN at that Company. The decided end state is that they raise it and you approve; that request flow is not built and is required before Live. Do not tell a customer that approval already happens.
Q: "I removed someone and they still show."
A: Removal revokes the membership; a second remove returns already_revoked. Their employment record is separate: ending employment is an employee change, not an access change.
Q: "An employee has no sign-in. Is that wrong?"
A: No. A cleaner can be employed and never sign in. A person can also have access and no employment. The link is the email, and is optional.
Q: "Can an employee see their own leave or payslip?"
A: Not yet. Self-service waits on the STAFF role decision.
Q: "Why is leave 1.75 days a month for my country?"
A: It is fixed for every Company today. A per-Company, per-jurisdiction policy is planned and not decided (P5).
Q: "Can the HR officer see bank details?"
A: No. Only the Owner Admin.

D. ERROR TOKENS YOU WILL SEE
forbidden (403), unauthorized (401), expired and already_responded (invite), already_revoked (409), company_not_in_tenant, module_not_yet_available (422), validation_failed. The Owner Admin cannot be removed: not_owner_admin / forbidden depending on the route.

E. WHAT TO COLLECT BEFORE ESCALATING
Tenant id, Company id, the acting person's role, the target membership id (not names where avoidable), the route and the error token, and the time. Never ask for a password, token, bank detail or ID number.

F. ACCEPTANCE LIST: THE PHONE CHECK FOR THE BUSINESS OWNER'S ACTS
Source: Femi, 2026-10-15: the Business Owner can run the business from a mobile device. WEB runs each check on a phone (about 400 px wide) before the screen ships; a screen passes only if EVERY check passes. Result values: Pass, Fail, Not built, Not yet tested. As of 2026-10-17 the Owner's approval screens for Personnel do not exist (the request flow is not built), so the per-act checks are Not built; the general checks also apply today to the direct Give access / Remove access / Invite screens.

General checks:
- PH-1 One screen at phone width shows who, what, the effect in access, and what happens next; no sideways scrolling.
- PH-2 Two-step decision: Approve or Reject; a reason is required on reject, optional on approve; no desktop-only second step.
- PH-3 Long lists are cards or summaries with openable detail, never a wide table scrolled sideways (the roster of Memberships and their grants especially).
- PH-4 Notices carry no figures and no names ("2 items need you"); detail only after sign-in.
- PH-5 Online only: nothing of the business's data is stored on the phone; any document is saved only by a deliberate, audited PDF download.
- PH-6 The result is confirmed on the same screen and audited, including a flagged self-approval.
- PH-7 A failed or partial result says in plain words what happened and what to do (for example Retry). A hire or access change whose first leg succeeded and second failed must say which.

Per-act checks:
- PEO-ACC-1 Approve a hire (UC-PEO-01): name, position, division, start date, employment type, whether system access is requested, who raised it. Approve or Reject. NOT BUILT.
- PEO-ACC-2 Approve an offboarding (UC-PEO-11): name, end date, what happens to their access, notes on final pay. Approve or Reject. NOT BUILT.
- PEO-ACC-3 Approve an access change (FR-PEO-19, give / change / remove): who, which Company, role and modules before and after, who raised it. Approve or Reject. NOT BUILT; REQUIRED BEFORE LIVE.
- PEO-ACC-4 Approve leave when the Owner is the approver (UC-PEO-07): who, dates, type, balance before and after, cover. Approve or Reject. (Leave approval exists in HR; its phone screen is Not yet tested.)
- PEO-ACC-5 See who needs attention (UC-PEO-12): overdue statements, expiring documents, probation ending, leavers; opens detail. Read only. NOT BUILT.
- PEO-ACC-6 Set the leave policy (UC-PEO-08): current rules and the change in plain words. Save or Cancel. NOT BUILT.
- PEO-ACC-7 Self-approval is flagged: when the Owner raises and approves their own access change it is recorded self-approved and shown flagged. NOT BUILT.

Access-flow acceptance (EA/HR/WEB, before Live):
- AC-1 A delegate (HR Officer with ADMIN) who starts Give access / Change access / Remove access creates a request, and nothing changes in EA until the Owner Admin approves.
- AC-2 The Owner Admin acting directly is approved in the same step and recorded selfApproved.
- AC-3 EA re-authorises the execution with the approver's own token; a request approved by a non-Owner is refused.
- AC-4 No screen says "Team" or shows a separate "Access" section; each employee row has Give access / Remove access and there is one "Invite someone who isn't an employee" button.

G. NOT BUILT, NOT DEPLOYED OR NOT YET EXERCISED (as of 2026-10-17)
- The StaffChangeRequest flow (hire, leaver, access grant / change / revoke) and the Owner approval screens: designed; required before Live.
- The Personnel rename and the per-row Give / Remove access screen in WEB: pending WEB.
- Position, division, line manager, contact and emergency contact on the employment record; terms record and statutory due dates; right-to-work record; document store; working-time record; absence record; onboarding and offboarding checklists; the Owner's attention report: designed (Personnel_Scope_SPUTO waves 2 to 5), none built.
- Configurable leave policy; employee self-service; disciplinary/grievance record; data-subject requests.
- Statutory duties per jurisdiction are not sourced (Sierra Leone from the primary Act and counsel); retention periods come from counsel, not from this sheet.
- No Personnel screen has been phone-checked.
