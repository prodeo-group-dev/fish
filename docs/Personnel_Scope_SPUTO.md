# Personnel (HR): what it is for, how deep it goes for an SME, and where "Team" lives (SPUTO)

**Status:** 2026-10-15, planning only, nothing built. Written by the EA session at Femi's request, relayed by CM ("what exactly is HR about and how deep into personnel management do we have to go for SMEs", Decisions_Log 2026-10-15 item 1: the Team home is not decided without this SPUTO). Same shape as `docs/Payroll_SPUTO.md`. Evidence tags: **[code]** read on `origin/master` of HR, EA or WEB on 2026-10-15; **[doc]** read in a repo doc; **[decided]** in the Decisions_Log; **[web]** from a public source cited in section 2; **[unverified]** not checked. No HR session is running, so HR facts come from HR's code on master, not from its owner.

**Name (Femi, 2026-10-15, via CM): the area is called PERSONNEL** ("Personnel is more appropriate and more professional"), so Administration > Personnel replaces "People" throughout this note, including the generic label for the HR module in WEB's vocabulary (today "People"). The school label for the same list stays "Staff" (D16) unless Femi says otherwise. **He has answered only the name: P1 to P6 in section 8 are still open, and this note's recommendations are recommendations, not decisions.** The file was renamed from `People_HR_Scope_SPUTO.md`; the old name is a one-line pointer.

**Answered 2026-10-15 (Femi, via CM; CM's reading, logged in the Decisions_Log, Femi may correct it): P1 and P2.** "Personnel, not Team. EA holds sway over HR. Let it stay in HR. That is where it should be." Read as: the feature formerly called Team is part of **Personnel** (no separate "Access" name), and **option A is adopted**: invite, roles, modules and remove stay in HR/Personnel under Administration, with EA remaining the system of record and authority (HR calls EA with the human's own token and EA re-authorises every call). **Option C, which this note recommended, is NOT adopted**; sections 5 to 8 are updated accordingly and keep C only as the record of what was weighed. **P3 (depth), P4, P5 and P6 are still open.**

**This document reopens one earlier decision and says so:** on 2026-09-29 Femi chose to move the Team surface (invite, roster, remove) into HR ("That feature needs to be there in HR"). Femi now asks the question again with the payroll split in view. Section 5 sets out the options; it does not treat the earlier choice as settled or as wrong.

---

## 1. Scope (S)

**The problem, in Femi's words:** Administration governs HR, and HR manages "Team" (a name he dislikes). Payroll is leaving HR. So what is HR about, how deep must personnel management go for a small business, what should "Team" be called, and does inviting people and giving them roles and modules belong to Personnel or to EA's access control?

**Three things are tangled under one word.** They have different owners, different audiences and different risks:

| Thing | Question it answers | Owner today | Example that shows they differ |
|---|---|---|---|
| **Employment** | Who works for this business, on what terms, from when to when, how much time off do they have, what must the business keep on file about them? | HR (Personnel) | A cleaner is employed and has no reason to sign in to FiSH. |
| **Access** | Who can sign in, as what role, to which modules, at what level, at which Company? | EA (Membership, `GET /me`; every service authorises against it) | The business's outside accountant signs in and is not an employee. The Owner Admin signs in and may not be on payroll at all. |
| **Pay** | What are they paid, what is withheld, what is owed to the authorities? | Payroll (`docs/Payroll_SPUTO.md`) | A pay run must not need to know who may sign in. |

**In scope:** what Personnel (HR) holds and does once Payroll has left; the depth of personnel management for an SME; the name and home of the invite, roles, modules and remove feature; how a hire becomes access; what changes on screen.

**Out of scope:** payroll, PAYE and pay terms (Payroll SPUTO); the authorisation model itself (RBAC SPUTO, frozen; the `STAFF` role question stays with Femi and CM); a recruitment pipeline (already decided against, D1 below); learning management; rostering and shift planning.

**Already decided and not re-litigated:** onboarding, including recruitment, and offboarding happen through HR (D1, 2026-10-06); an HR Officer may trigger and only the Owner Admin approves (D2, D7, D8); the Owner Admin is the sole approver; staff are grouped by **division** (Operations, Administrative, Finance) and the kind of staff is the division on the employment record (2026-10-13); the school's label for the people list is "Staff" (D16, 2026-10-13); HR is the source of truth for employment and EA derives access from the position through a mapping EA owns (Staff Onboarding SRS D4); Payroll takes pay terms, bank details, advances and expense reimbursement; HR keeps pay basis; the request forms stay in Personnel (2026-10-15).

---

## 2. What is true today (evidence)

| # | Finding | Tag |
|---|---|---|
| E1 | HR's `Employee` holds: name, email, bank details, employment type (SALARIED, HOURLY, UNPAID), pay rate and frequency, standard working days, contracted hours, start date, end date. **There is no** position or job title, division, line manager, phone, address, emergency contact, date of birth, right-to-work record, contract or terms record, document, or probation field. | [code] `employee.kt`; grep for these names finds nothing in HR's main code |
| E2 | Leave exists: annual and sick leave requests, approve and reject (APPROVE access level), balances. The policy is **hard-coded**: annual leave accrues at 1.75 days per month and sick entitlement is 10 days a year, for every Company in every jurisdiction. | [code] `leave_balance_calculator.kt`, `leave_type.kt` |
| E3 | Employee changes are audited (V9) and the email is canonical and unique (V14). Unpaid people (volunteers, governors) are modelled with the UNPAID type. | [code] migrations V9, V11, V14 |
| E4 | WEB's People screen (today's name; to be renamed Personnel) has four sections: Employees, Pay runs, Salary advances, **Team**; "Add employee" and "Run payroll" are actions on the Employees screen. | [code] WEB `peopleViews.ts`, `HrTab.tsx` |
| E5 | The "Team" tab invites, lists and removes **EA Memberships**. HR's `POST /team`, `GET /team`, `DELETE /team/{membershipId}` are thin proxies that forward the caller's own token; EA re-authorises and executes every call. The data and rules are EA's. HR's own code says Memberships "don't necessarily correspond 1:1 to an Employee row". | [code] HR `TeamRoutes.kt`, `ktor_ea_gateway.kt` |
| E6 | HR also links an Employee to a Membership by email to show and edit "module responsibilities". | [code] `StaffResponsibilityRoutes.kt` |
| E7 | The hire and leave flow designed on 2026-10-06 (`StaffChangeRequest`: raise, Owner approves, execute HR then EA then ER, per-leg status) is **not built**. The direct paths (`POST /employees`, `PUT /employees/{id}` end dates, `/team`) are the only ones. | [doc] `Staff_Onboarding_Offboarding_SRS.md`, HR's half; [code] no `StaffChangeRequest` |
| E8 | No document storage exists in HR (contracts, ID, certificates). No payslip, no staff working-time record, no disciplinary or grievance record, no appraisal code (the 360 appraisal is a stored reference document, with compensation linkage decided against). | [code], [doc] `Staff_Appraisal_360_Requirements_Use_Cases.md` |
| E9 | School vocabulary: People/Employees (today's words) maps to "Staff" for a school; the label for Team was set to "Staff" grouped by kind (D16), and the collision with "Staff and roles" was left for ER and WEB to reconcile. | [decided] Decisions_Log 2026-10-12, 2026-10-13 |
| E10 | The Team move (WEB G16 and G27) is waiting on this SPUTO. | [decided] Decisions_Log 2026-10-15 |

**What the law expects a small employer to keep and issue** (a floor for the depth question; check with counsel per Company before relying on it):

- **UK:** a written statement of the main terms on or before the first day of work; the wider statement within two months; any change in writing within a month. Right-to-work checks before work starts, with a copy of the documents and the check date kept for the employment and two years after. [Acas: when an employee must get their written statement](https://www.acas.org.uk/what-must-be-written-in-an-employment-contract/when-an-employee-must-get-their-written-statement); [GOV.UK employer's guide to right to work checks](https://www.gov.uk/government/publications/right-to-work-checks-employers-guide/employers-guide-to-right-to-work-checks-26-june-2025-accessible). [web]
- **Ireland:** the core terms in writing within five days of starting, the rest within a month (an older WRC page says two months; the current date-specific rule needs checking); the employer keeps the statement through the employment and a year after; working-time records (hours, leave, rest) kept for three years. [WRC terms of employment](https://www.workplacerelations.ie/en/what_you_should_know/employer-obligations/terms-of-employment/); [Citizens Information: working-time records](https://www.citizensinformation.ie/en/employment/employment-rights-and-conditions/hours-of-work/employment-working-time-records/). [web]
- **Sierra Leone:** the Employment Act 2023 is the governing law; summaries say a contract over three months must be written, written particulars are due within 12 weeks, and contracts may need vetting by the Labour Commissioner. These come from secondary sources that disagree in places; the leave and record-keeping sections were **not** found. [The Employment Act 2023 (Parliament of Sierra Leone)](https://parliament.gov.sl/uploads/acts/The_Employment_Act_2023.pdf). [web, unverified]

---

## 3. What Personnel (HR) is for

**One sentence:** Personnel holds the **employment record and the employment relationship**: who works for the business, on what terms and dates, in which division and position, what time off they have and take, and the documents and statutory duties that go with employing someone.

**It is not:** pay (Payroll), sign-in rights (EA's access control), school duties (the Education Runtime), or recruitment.

**Rules that keep the boundary clean:**
1. Personnel holds facts about the **person and the employment**; Payroll holds **money**; EA holds **access**; ER holds **school duties**. One employee id everywhere, never a copy.
2. A person can be an employee with no access (a cleaner), have access and no employment (an outside accountant), or both. The link is optional and is the email.
3. Hiring is the one place Personnel and access meet: an approved hire may carry "needs system access", executed as a leg through EA (the 2026-10-06 design, unchanged).
4. Personnel reads nothing from Payroll except, optionally, a "paid" marker for display; Payroll reads employment records and unpaid-leave days from Personnel (two narrow flows, per the split research note).

---

## 4. How deep for an SME (Requirements, MoSCoW)

The test applied: **what must a business of 3 to 50 people be able to do in FiSH without a separate spreadsheet, and what would it be unlawful or unsafe not to keep?** Larger-organisation features are named and parked so nobody builds them by accident.

**Functional (FR-PEO-n)**

| ID | Requirement | MoSCoW |
|---|---|---|
| FR-PEO-01 | **Employment record:** name, contact (email, phone), position (a closed list, `STAFF`, `TEACHER`, `NON_TEACHING_STAFF`, extensible by code), **division** (Operations, Administrative, Finance), employment type, start and end date, line manager, work location, probation end. Nothing else is collected without a stated purpose (data minimisation). | Must |
| FR-PEO-02 | **Emergency contact** for each person. | Must |
| FR-PEO-03 | **Terms record:** the contract or written statement is recorded (document or generated) with the date issued and the statutory due date computed per jurisdiction (UK day one and two months, Ireland five days and one month, others as sourced); an overdue statement is shown to the Owner. | Must |
| FR-PEO-04 | **Right-to-work and identity record** where the jurisdiction requires it: document type, check date, expiry, who checked; the copy kept for the legal period. | Must where required (UK); Should elsewhere |
| FR-PEO-05 | **Documents:** a restricted store for contracts, ID and certificates, with expiry dates and reminders; every download audited; retention per jurisdiction. | Should (Must if FR-PEO-03 or 04 store a copy) |
| FR-PEO-06 | **Leave:** annual, sick and other leave types; requests, approval by the line manager or Owner, balances; **policy per Company and jurisdiction** (accrual rate, entitlement, carry-over), replacing the hard-coded 1.75 days a month and 10 sick days. | Must |
| FR-PEO-07 | **Absence record:** sickness and other absence by date, with the sick-note flag, visible to the Owner and the person's manager; unpaid days flow to Payroll. | Must |
| FR-PEO-08 | **Working-time record** (hours, rest, leave) where the law requires it (Ireland, three years): staff time entry or an attendance import, kept for the legal period. | Should (Must for Ireland-first customers) |
| FR-PEO-09 | **Onboarding:** a hire request raised by an HR Officer or the Owner, approved by the Owner Admin only, with a checklist (contract issued, right-to-work done, emergency contact, access given, equipment) and per-step status. | Must |
| FR-PEO-10 | **Offboarding:** an end-date request, approved by the Owner Admin, with a checklist (access removed, equipment, final pay noted, documents retained), and a visible consequence summary. | Must |
| FR-PEO-11 | **Position, division or line-manager change** recorded with date and who. | Must |
| FR-PEO-12 | **Change history:** every change to the record audited in the platform shape (actor, time, before and after for sensitive fields). | Must |
| FR-PEO-19 | **Access changes need the Business Owner's approval** (Femi, 2026-10-15: "if initiated here, it must be approved by the Business Owner"). Inviting someone, changing a role or module, and removing access, when started from Personnel by anyone other than the Owner Admin, become a **request** that only the Owner Admin approves, then EA executes (EA re-authorises with the approver's own token). When the Owner Admin starts one it is approved in the same step, recorded as self-approved. Same machinery and rules as the hire request (D2, D7, D8, FR-PEO-09). | Must |
| FR-PEO-13 | **Reports for the Owner:** headcount by division, starters and leavers, leave liability, expiring documents, statements overdue, probation ending. | Should |
| FR-PEO-14 | **Employee self-service:** see own record and leave balance, request leave, update own contact details, later view payslips. Requires the employee to hold a sign-in, which needs the generic `STAFF` role (a pending authorisation decision). | Should (blocked on the `STAFF` decision) |
| FR-PEO-15 | **Disciplinary and grievance record:** confidential notes and outcomes, visible only to the Owner Admin and named HR roles, retention per jurisdiction. | Should |
| FR-PEO-16 | **Data-subject requests:** export and erase a person's data within retention rules (the HR backlog's Epic 5). | Should |
| FR-PEO-17 | **Simple annual review** (one form, manager and employee, no scoring tied to pay). | Could |
| FR-PEO-18 | 360 appraisal, training and development, succession, skills matrix, recruitment pipeline (adverts, applicants, interviews), rostering, benefits administration, org-chart designer. | **Won't now** (named, parked; the 360 document stays reference-only and compensation stays separate by the existing decision) |

**Non-functional (NFR-PEO-n)**

| ID | Requirement |
|---|---|
| NFR-PEO-01 | Personal data is minimised, role-restricted (an HR Officer sees people records, never bank details; the Owner Admin sees bank details), and audited; no personal figures or names in notifications or logs. |
| NFR-PEO-02 | Retention periods are per jurisdiction and stored as data; the periods are **not set here** and come from counsel. |
| NFR-PEO-03 | Statutory timers (statement due dates, right-to-work expiry, probation end) are computed and shown, never relied on a person remembering. |
| NFR-PEO-04 | Contract fixtures for every cross-service payload (Personnel to EA access leg, Personnel to Payroll flows), strict decode, consumer first. |
| NFR-PEO-05 | Hire and leave execution is crash-safe and retryable (the approval-lease and per-leg status machinery already designed for payroll approval). |
| NFR-PEO-06 | Vocabulary per industry through WEB's existing label vocabularies: a school says "Staff", generic says "Personnel"; the model underneath is one. |

---

## 5. Where invite, roles, modules and remove live, and what to call it

**Decided 2026-10-15 (Femi, via CM): option A.** The invite, roster, role and module changes, and remove stay in HR under Administration > Personnel. EA stays the system of record and the authority: HR's `/team` routes forward the caller's own token and EA re-authorises and executes every call, exactly as built on 2026-09-29. **The name is Personnel; there is no separate "Access" name.**

**Approval rule, added 2026-10-15 (Femi): "if initiated here, it must be approved by the Business Owner".** Today an HR Officer holding ADMIN at a Company can invite staff, change modules and remove staff directly, with no Owner approval (`Membership.canManageStaffAt`, EA). That is stricter than the code. The end state is FR-PEO-19: a delegate **raises** the change in Personnel, only the Owner Admin approves, then EA executes. The Owner Admin acting directly is approved in the same step. Until the request flow exists, the interim is an open question (P7).

**What this means in practice: almost nothing has to be built, because it is already built.** Read on `origin/master` on 2026-10-15: EA has `DELETE /tenants/{tenantId}/memberships/{membershipId}` (`RemoveStaffMemberUseCase`); HR has `POST /team`, `GET /team`, `DELETE /team/{membershipId}` and the EA gateway calls behind them; WEB has `TeamTab` inside `HrTab`, and EA's old `TeamPanel.tsx` is gone. The 2026-09-29 move is complete and live, so "the Team move is back on" means: **stop planning to undo it, and finish what is still missing around it.**

**Options weighed (kept for the record):**

| Option | What it means | Outcome |
|---|---|---|
| **A: all in Personnel** | The access feature stays a section of Personnel; HR proxies it to EA. | **Adopted.** One place for "my people"; no screen moves. Known cost, accepted: two audiences share a section (an HR Officer managing records versus someone who grants system access), and people with access but no employment (the outside accountant) still appear in a Personnel roster. EA's per-Company rules (`canManageStaffAt`) already decide who may do what inside it. |
| B: all in EA's access control | Undo the move. | Not adopted. |
| C: split by who the person is | Personnel owns employment and triggers access for a hire; a separate EA Access screen owns the rest. | Not adopted (was this note's recommendation). |

**P1b answered 2026-10-15 (Femi: "Agreed. My thoughts exactly"): no separate screen and no new label.** Each employee row gets "Give access" or "Remove access" (and a way to change their role or modules), and one button, **"Invite someone who isn't an employee"**, covers a person such as the outside accountant. Every one of these acts follows the approval rule above (FR-PEO-19): the Owner Admin acts directly, anyone else raises a request the Owner Admin approves. Detail left to WEB: where a person who has access but is not an employee is shown (a marker in the same list), which this note does not decide.

**What changes on screen (WEB's to build, not EA's):**
- Administration sections: Dashboard, **Personnel**, Companies, Verification (Payroll moves to Finance with the payroll split). No separate Access section.
- Personnel sections: Employees (with Add employee, and per-row Give access, Change access and Remove access, plus the button "Invite someone who isn't an employee"; no separate Team or Access section), Leave, Onboarding and leavers, Documents (when built). Pay runs and Salary advances move to Payroll under Finance.
- HR's `/team` proxies **stay**. The earlier plan to retire them is withdrawn.

---

## 6. Use cases (U)

| UC | Name | Actor and module | Summary | Traces |
|---|---|---|---|---|
| UC-PEO-01 | Hire a person | HR Officer or Owner raises; Owner Admin approves; HR | Raise with name, position, division, type, dates, and "needs access"; Owner approves; HR creates the employment; if access is needed EA grants it; checklist starts. A failed leg is shown and retryable. | FR-PEO-01, 09; NFR-PEO-05 |
| UC-PEO-02 | Keep the terms record | HR Officer | Record or generate the written statement; the due date is computed per jurisdiction; overdue shown to the Owner. | FR-PEO-03 |
| UC-PEO-03 | Record right to work | HR Officer | Document type, check date, expiry, copy filed. | FR-PEO-04, 05 |
| UC-PEO-04 | Maintain a person's record | HR Officer, WRITE | Change contact, position, division, line manager, with audit. Bank details and pay are not here. | FR-PEO-01, 02, 11, 12 |
| UC-PEO-05 | File and find documents | HR Officer | Upload, expiry reminder, restricted download, audit. | FR-PEO-05 |
| UC-PEO-06 | Request leave | Employee or HR Officer on their behalf | Choose type and dates; balance shown; manager notified. | FR-PEO-06, 14 |
| UC-PEO-07 | Approve or reject leave | Line manager or Owner, APPROVE | Decide with reason; balance updated; unpaid days flow to Payroll. | FR-PEO-06, 07 |
| UC-PEO-08 | Set the leave policy | Owner Admin | Accrual, entitlement, carry-over per Company and jurisdiction. | FR-PEO-06 |
| UC-PEO-09 | Record absence | HR Officer or manager | Dates, reason category, sick-note flag. | FR-PEO-07 |
| UC-PEO-10 | Record working time | Employee or HR Officer | Hours and rest where required; kept for the legal period. | FR-PEO-08 |
| UC-PEO-11 | Offboard a person | HR Officer or Owner raises; Owner Admin approves | End date; checklist; access removed through EA; final pay noted; documents retained. | FR-PEO-10 |
| UC-PEO-12 | See who needs attention | Owner Admin | Overdue statements, expiring documents, probation ending, leavers this month. | FR-PEO-13 |
| UC-PEO-13 | Handle a data-subject request | Owner Admin or HR Officer | Export or erase within retention rules. | FR-PEO-16 |
| UC-PEO-14 | Record a disciplinary or grievance | Owner Admin or named HR role | Confidential record, restricted view. | FR-PEO-15 |
| UC-ACC-01 | Give access to someone who is not being hired | Owner Admin directly; a delegate raises a request the Owner Admin approves (FR-PEO-19) | Invite by email with role, level, modules at chosen Companies. | Section 5 |
| UC-ACC-02 | Change or remove access | same rule | Change role or modules; remove; the Owner Admin cannot be removed. | Section 5 |
| UC-ACC-03 | See who can sign in | same | Shown on each employee row (has access or not) and, for someone who is not an employee, as a marked entry in the same list; the roster of Memberships with their grants remains EA's data. | Section 5 |

(UC-ACC are the roster and invite section inside Personnel; they already exist as routes in HR that call EA, and are listed so the access side is complete.)

---

## 7. Tasks (T) and order (O)

| # | Item | Owner | Depends on |
|---|---|---|---|
| **Wave 0: decisions (Femi, via CM)** | | | |
| 0.1 | P3 to P7 (section 8); P1, P1b and P2 are answered | Femi | none |
| 0.2 | Statutory duties sourcing per jurisdiction (statement due dates, right-to-work, working-time, retention), with Sierra Leone from the primary Act and counsel | HR with Femi; counsel | none |
| 0.3 | Confirm or assign an HR owner session | CM, Femi | none |
| **Wave 1: no code, wording and boundaries** | | | |
| 1.1 | Rename People to Personnel on screen; per-row Give, Change and Remove access and the button "Invite someone who isn't an employee" instead of the Team section; Payroll sections to Finance (with the payroll split). No Access section and no new label | WEB | none |
| 1.2 | Reconcile D16: school "Staff" = the people list; Access has one name for all industries | ER, WEB | 0.1 |
| 1.3 | ~~EA publishes the Access contract and marks HR's `/team` proxies to be retired~~ **Withdrawn (option A adopted).** EA's membership routes stay as they are and remain the contract HR calls | EA | none |
| 1.4 | Already done, no work: EA's `DELETE .../memberships/{membershipId}`, HR's `/team` routes and their EA gateway calls, WEB's `TeamTab`, EA's `TeamPanel.tsx` removed (all on master). Only residual check: that nothing still points at the old "People" or "Team" wording after the Personnel rename | EA, HR, WEB | none |
| **Wave 2: the employment record** | | | |
| 2.1 | Extend the employment record: position, division, line manager, contact, emergency contact, probation end; consumers declare first (WEB, EA mirror); fixtures | HR, WEB | 0.3, 1.2 |
| 2.2 | Leave policy per Company and jurisdiction (replace the hard-coded numbers); migration keeps today's values as the default | HR | 0.2 |
| 2.3 | Absence record | HR | 2.1 |
| **Wave 3: the flows** | | | |
| 3.1 | Hire, leave and **access-change** request machinery (`StaffChangeRequest`, with kinds for access grant, access change and access revoke so FR-PEO-19 uses the same approve-and-execute path: approve, execute HR then EA then ER, per-leg status, approval lease) with the "needs access" leg through EA | HR, EA, ER | 2.1, EA's position-to-role mapping, Femi's `STAFF` decision for non-school hires |
| 3.2 | Close the direct paths: employee create and end-date change become Owner-only direct acts; delegates use the request route | HR | 3.1 |
| 3.5 | **Interim (P7):** until 3.1 exists, delegates are refused on EA's invite, modules and remove routes (an add-a-deny change in EA, about 0.5 day with tests; WEB hides the controls from delegates); the Owner Admin keeps the direct path | EA, WEB | P7, CM review |
| 3.3 | ~~Retire HR's `/team` proxies~~ **Withdrawn (option A adopted).** Keep them | HR | none |
| 3.4 | Onboarding and offboarding checklists | HR, WEB | 3.1 |
| **Wave 4: statutory duties and files** | | | |
| 4.1 | Terms record and statutory due dates with Owner-visible overdue list | HR | 0.2, 2.1 |
| 4.2 | Right-to-work record | HR | 0.2, 2.1 |
| 4.3 | Document store: encrypted object storage, restricted access, expiry reminders, audited downloads | HR, CM (storage, keys) | 4.1 or 4.2 |
| 4.4 | Working-time record for jurisdictions that require it | HR | 0.2 |
| **Wave 5: seeing and self-service** | | | |
| 5.1 | Owner's attention report for people (UC-PEO-12), a source for the dashboard | HR, EA | 4.1 |
| 5.2 | Employee self-service | HR, WEB, EA | 3.1, `STAFF` decision |
| 5.3 | Disciplinary and grievance record; data-subject requests | HR | 4.3 |
| 5.4 | Simple annual review (only if Femi wants it) | HR | later |

**Critical path:** 0.1, then 1.1 and 2.1, then 3.1. Waves 1 and 2 do not depend on the payroll split; 3.1 is independent of it too, but the Payroll sections leaving Personnel (1.1) should land with it so Personnel is not renamed twice.

---

## 8. Decisions asked of Femi (one batch, via CM)

1. ~~**P1, the name**~~ **Answered 2026-10-15:** Personnel; the feature formerly called Team is named Personnel (no "Access"). ~~**P1b**~~ **Answered:** no separate section and no new label; per-row "Give access" / "Remove access" and a button "Invite someone who isn't an employee".
2. ~~**P2, the home**~~ **Answered 2026-10-15:** option A: it stays in HR/Personnel under Administration; EA stays the system of record and authority.
3. **P3, the depth:** approve section 4's Must, Should, Could and Won't lists for an SME. Particular calls: documents store in the first release (Should), disciplinary and grievance record (Should), staff working-time record (Must only where the law requires it), 360 appraisal parked (Won't now).
4. **P4, jurisdictions first** for statutory timers: UK and Ireland (sourced); Sierra Leone after the primary Act and counsel confirm.
5. **P5, the leave policy:** configurable per Company and jurisdiction (recommended), or keep one fixed policy for now?
6. **P6, self-service:** employee self-service waits on the generic `STAFF` role decision; asking again so it is not forgotten.
7. **P7, the interim for access changes** (FR-PEO-19): until the request flow is built, **refuse delegates** (an HR Officer with ADMIN) on invite, change modules and remove, leaving the Owner Admin the only one who can act (recommended: it matches Femi's rule now and is an add-a-deny), or keep delegates acting directly until the flow exists?

## 9. What I could not verify

- The statutory details beyond the cited pages; Sierra Leone's leave and record-keeping sections; the Irish "one month versus two months" timing for the remaining terms; current UK changes after the cited guidance.
- HR's code beyond the files named (no position, division, line manager or contact fields exist; I searched by name, not by reading every file).
- Whether WEB's items G16 and G27 mean what I infer (that they wait for this); WEB should confirm.
- Any production data; whether any Company already holds employees without a Membership, or Memberships without an employee (this count would size the link between Personnel and Access).
- A document store: whether the platform already has encrypted object storage I can reuse (CM).
