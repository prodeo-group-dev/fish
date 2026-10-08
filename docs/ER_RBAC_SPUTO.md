# Education Runtime (EduSys) RBAC: Scope, Plan, Use cases, Tasks, Order (SPUTO)

**Owner:** +ER Education (the Education Runtime session). **Status:** DRAFT v0.1, 2026-10-08, docs only. **Parent document:** `docs/RBAC_SPUTO.md` v0.2 (CM). This is the runtime's own RBAC SPUTO that its section 4 (T13, T18) and requirement R12 ask for. It follows the platform's principles P1-P10 and requirements R1-R13 and does not restate them.

**Checked against:** the Education Runtime repo at `origin/master` (ER production task `:74`, image `d4f2c66`, with first-admin and S1 A1+A2 live) for every **[verified]** item below, with file and line references. A3 (mark entry, V34/V35) is on branch `feature/s1-assessment-cycle`, reviewed by CM and being released; where this document says "A3", that is the branch, not yet master.

**Freeze compliance:** nothing in this document has been built. S1 continues on existing predicates (`canEnterGrades`, `canManageAssessmentSetup`, `canViewAssessmentSetup`, plus "one of this offering's teachers"). Every new role, capability or predicate the plan below needs is listed in section 6 and will be asked of CM before it is written.

---

## 1. Scope

### What the Education Runtime authorizes

- **School staff** (human): roles held per school in ER's own table `staff_assignments` (free-form strings today, one row per `(school, email)`). EA does not hold school roles; it only seeds the first `SCHOOL_ADMIN` through `PUT /schools/{id}/first-admin` (live, service-account only, grants only while the school has no active admin).
- **Guardians / parents** (human): not stored. `GUARDIAN` is computed whenever the sign-in email matches a guardian on any student at the school (`SchoolStore.hasGuardianLink`).
- **A device role** (machine): the DPID service audience resolves to `DEVICE_ATTENDANCE_CAPTURE`.
- **Service audiences**: `dpid` (attendance capture and student lookup), `ea-provisioning` (`POST /schools`, `PUT /schools/{id}/first-admin`). Outbound, ER calls SOP with its own Cognito service account (guardian-as-customer); it never calls GL or EA.
- **Registered devices** (trust of a teacher's phone for the offline sync): a separate control, covered only where it touches authorization.

### How ER differs from the other services

ER does **not** use EA's `GET /me`, `AccessLevel` or module grants. Its model is "roles per school", resolved after the JWT is verified. The platform's capability vocabulary (view, enter, approve, administer) therefore has to be **mapped onto** ER's roles (section 2.3), as R12 requires, instead of read from EA. The identity is the JWT `email` claim; since first-admin went live, staff subjects are matched case-insensitively (trim + lower-case); guardian matching is still exact.

### Out of scope here

Live-switch security scope (rate limits, backups, row-level security), the Tenant-level owner model in EA, payment-provider design (Epic 13), and the school's own policies (who is the form master of which class; those are data, not rules).

### Current state, route by route **[verified against origin/master]**

| Area | Routes | Predicate today | Who that is |
|---|---|---|---|
| Register | student create/CSV/list/photo/transfer/DPID link, devices, **staff assign/list/revoke** | `canManageRegister` | SCHOOL_ADMIN, REGISTRAR |
| Admissions | create, list, transition (to ENROLLED) | `canManageAdmissions` | SCHOOL_ADMIN, REGISTRAR, ADMISSIONS_OFFICER |
| Timetable and catalogues | lessons, rooms, teachers, terms, teacher-subjects | `canManageTimetable` | SCHOOL_ADMIN, TIMETABLER |
| Attendance, sync | mark, auto-capture, sync push/changes | `canMarkAttendance` | TEACHER, SCHOOL_ADMIN, HEAD_TEACHER, HOD, HOY, **DEVICE_ATTENDANCE_CAPTURE** |
| Teaching | class roster, curriculum, legacy assessments (structure, grade, publish) | `canEnterGrades` | TEACHER, SCHOOL_ADMIN, HEAD_TEACHER, HOD, HOY |
| Assessment set-up (S1) | grading scales, structures, offerings (admin list) | `canManageAssessmentSetup` / `canViewAssessmentSetup` | SCHOOL_ADMIN / plus the teaching roles for reads |
| Marks (S1 A3) | enter, batch, submit, roster, detail | `canEnterGrades` **and** one of the offering's teachers | no administrator bypass; history read is SCHOOL_ADMIN |
| Fees | schedule, issue invoice, resolve guardian, confirm payment, list, reconcile | `canManageFees` | SCHOOL_ADMIN, FEE_OFFICER, BURSAR |
| Parent gateway | child summary, **pay invoice** | `canAccessParentGateway` | GUARDIAN, PARENT (summary checks the guardian link; see ER-F3/ER-F5) |
| Safeguarding | student audit log, safeguarding flag content | `canAccessSafeguarding` | SCHOOL_ADMIN, SAFEGUARDING_LEAD, PASTORAL_LEAD |
| DPID lookup | student by DPID identity | `canLookupByDpidIdentity` | SCHOOL_ADMIN, REGISTRAR, DEVICE_ATTENDANCE_CAPTURE |
| Single student | `GET /students/{id}` | **none beyond "has any affiliation"** | anyone resolved at the school |

### Findings (re-verified, then ER's own additions)

Evidence is `src/main/kotlin/com/theprodeogroup/educationruntime/...` at `origin/master`; line numbers are from `infrastructure/web/Application.kt` unless a file is named.

**ER-F1 = platform F4 (HIGH) [verified]: a REGISTRAR can grant SCHOOL_ADMIN.** `POST /schools/{id}/staff` (line 964), `GET .../staff` (975) and `POST .../staff/{subjectId}/revoke` (981) are all gated by `canManageRegister`, which includes REGISTRAR. The body is `subjectId|role1,role2`; any non-blank role string is accepted and **stored as typed** (`StaffAssignmentStore.assign` replaces the row's roles wholesale). So a REGISTRAR can (a) make anyone a SCHOOL_ADMIN, (b) reassign an existing admin down to another role, and (c) revoke an admin. There is no closed list of role names and no rule that a grantor may only grant what they hold.

**ER-F2 = platform money-loop finding (HIGH) [verified]: the whole fee loop is one predicate.** `canManageFees` (SCHOOL_ADMIN, FEE_OFFICER, BURSAR) guards define-schedule (645), issue-invoice (657), resolve-guardian (672), **confirm-payment (690)**, list, and reconcile (749). One person can define the price, bill the family and mark it paid, with no second person. Confirmation is also a **stub** (`FeeService.confirmPaymentStub`) with no payment provider behind it.

**ER-F3 (HIGH, ER-specific) [verified]: a guardian can mark their own child's invoice PAID.** `POST .../parent/invoices/{id}/pay` (737) calls `confirmPaymentStub`, which for a linked guardian sets the invoice `PAID` and writes a `StudentPaymentReceived` event to the outbox. Today the outbox is not delivered anywhere (BK-FIN-12), so no money moves. The day a relay exists, any parent can declare their own payment into SOP and the ledger. Payment must be confirmed by a provider or by reconciliation against a bank record, never by the payer's click.

**ER-F4 = platform F8 (MEDIUM) [verified, narrower than the survey said]: `GET /students/{id}` has no per-child check** (line 214: `requireSchoolAccess(identity, schoolId)` with no predicate). Any principal resolved at the school, including a GUARDIAN of any **one** child and the DPID device role, can read **any** student's `StudentDto`. That DTO is narrower than the whole profile: id, school, `externalRef` (admission reference), given and family name, class section, photo URL and **`hasSafeguardingFlag`**. It does **not** include date of birth, medical notes, guardian contacts or the flag's content. The exposure is still real: every parent can look up any child's name, class and photo by id, and see which children are flagged for safeguarding. By contrast `parent/children/{id}/summary` does check the guardian link (`ParentGatewayService.isLinkedGuardian`).

**ER-F5 = platform F6 (MEDIUM) [verified]: the DPID device role works at any school.** `CognitoErIdentityGateway.resolveForSchool` returns `DEVICE_ATTENDANCE_CAPTURE` for the `dpid` audience for **whatever `schoolId` is in the URL**, with no binding of the credential to schools. It can mark attendance and look up students by DPID identity anywhere, and (through ER-F4) read any student summary. Its capabilities are deliberately narrow; its **scope** is unbounded.

**ER-F6 = platform "role strings free-form, exact-case" (MEDIUM) [verified]:** `ErPrincipal.hasAnyRole` is an exact string match, so a staff row typed `Teacher` or `school_admin` silently grants nothing (fail-closed, but invisible), while a typo-free arbitrary string can be granted by ER-F1. Since the first-admin change, **subject** matching is case-insensitive; **role** strings and **guardian-link** matching (`hasGuardianLink`, `isLinkedGuardian`) are still exact.

**ER-F7 (MEDIUM, ER-specific) [verified]: the legacy assessment routes have no ownership or second person.** `POST /assessments/structures`, `/assessments/grades` and `/assessments/publish` need only `canEnterGrades`: any teacher can define a structure, enter a grade for **any** student, and **publish** (which emits `AssessmentCompleted`). They are replaced by S1 (A8 removes them, with CM's separate gate); until then they are the weak path.

**ER-F8 (MEDIUM, ER-specific) [verified]: `SCHOOL_ADMIN` bundles all four capabilities.** It is in every predicate above: administer (staff, set-up, timetable), enter (attendance, grades, register), money (fees), and safeguarding access. Under the platform's D1 (administer never includes posting or approving) this role has to be split in meaning, not just renamed (section 2.3).

**ER-F9 (LOW) [verified]: admissions has one actor for create and for every transition to ENROLLED** (`canManageAdmissions`); enrolment creates a student and may trigger billing, so it is a small version of the creator/approver gap.

**Platform F1 (fail-open verifier) does not apply to ER [verified].** There is no `?: verifier` fall-back: `CognitoErIdentityGateway` takes the DPID and EA verifiers as nullable and, when one is null, simply never recognises that audience, so a human token can never be treated as a service account. What ER lacks is R6's second half: it **starts quietly** with an audience unset (EA provisioning or DPID capture silently off) instead of refusing to start. Proposed in T-ER9.

---

## 2. Plan

### 2.1 How the platform principles apply

| Principle | In the Education Runtime |
|---|---|
| P1 Read and write differ | Seeing a class is not entering its marks; the admin list of offerings is not the right to write marks (already true in A3: no administrator bypass). |
| P2 Owner is oversight, not financial write | The school's **proprietor** (the Tenant's Owner Admin) oversees and administers; the head teacher runs results. Neither posts fees or confirms payments by virtue of the title (open decision D-ER1). |
| P3 Creator is not approver | Applied to results (2.4), fees (2.5), admissions, staff grants. |
| P4 Fail closed | Closed role list; unknown role string refused at write time; unset audience refuses to start. |
| P6 Per-Company/school | Every ER decision is at the URL's `schoolId`, resolved from that school's own rows; the DPID role and EA audience must become per-school (D-ER5). |
| P7 Scoped service identities | `dpid` and `ea-provisioning` get an allow-list of schools/Tenants; ER's outbound SOP account stays single (the platform's D5 decides). |
| P8 Server decides | Already true; WEB gets capabilities from a `GET /schools/{id}/me` ER route (backlog) instead of inferring from role names. |
| P9 Attributable | Marks and history record the token's email; approvals will too; staff grants record `grantedBy` (exists) plus before/after (new). |
| P10 Runtimes extend, not fork | This document is that extension: ER keeps its own role table but speaks the platform's four capabilities. |

### 2.2 Requirements (ER-R)

- **ER-R1 Closed vocabulary.** School role names come from one closed list (2.3); the staff routes reject anything else with a stable code; stored values are canonical upper-case; a one-off migration normalises existing rows.
- **ER-R2 Grant cap.** A grantor can grant only roles they hold **and** only roles their own role is allowed to grant (table 2.3). Only a SCHOOL_ADMIN can grant or revoke SCHOOL_ADMIN; nobody changes their own roles; the last active SCHOOL_ADMIN cannot be revoked or demoted (the proprietor re-seeds through first-admin if ever needed).
- **ER-R3 Approvals are a separate capability and come from the token.** The approver's identity is never read from a body field, and the creator cannot be the approver (P3), with the Owner exception of D6 to be decided for schools (D-ER1).
- **ER-R4 Money.** Defining prices, issuing an invoice and confirming payment are three duties; confirmation comes from a provider event or a bank reconciliation record, never from a user or the payer. A guardian's "I paid" can only create a **payment claim** for staff to verify.
- **ER-R5 Per-child access.** A GUARDIAN reads only children they are linked to (student read, summaries, invoices); staff read by role and, for teachers, by class.
- **ER-R6 Service scope.** Each service audience is bound to the schools/Tenants it may act for; the school is validated, not trusted from the URL alone.
- **ER-R7 Identity.** One canonical email form at the token boundary for staff **and** guardians (R9); `sub` is recorded next to the email for audit.
- **ER-R8 Capabilities endpoint.** `GET /schools/{id}/me` returns the caller's capability codes and, per resource, `allowedActions`, so WEB never infers rights from role names (R11).
- **ER-R9 Fail-closed start-up.** The service refuses to start in production mode if a required audience or issuer is unset.

### 2.3 Role map: school roles onto the platform capabilities (R12)

Platform capabilities: **V**iew, **E**nter (create and edit drafts and operational records), **A**pprove (approve or reject another person's record), **D**= Administer (people and configuration). ADMINISTER never includes posting or approving (D1). Role data stays in ER's `staff_assignments`; the closed list below is the proposal. Cells show what each role holds; "own" means limited to their own classes/offerings/records.

| Role (closed list) | Held by | V | E | A | D | Notes |
|---|---|---|---|---|---|---|
| `SCHOOL_ADMIN` | the school's operations head | all school data except safeguarding content | register, timetable, admissions, catalogues | none (see D-ER2) | staff grants, assessment set-up, devices | today also enters grades and fees; proposed to lose those (D-ER2) |
| `HEAD_TEACHER` | the principal | all academic data | own offerings if they teach | **results: class approval fallback, release**, corrections after release | none | the S1 `RELEASE_RESULTS` holder |
| `FORM_MASTER` | a per-class **assignment**, not a role string | own class | class ratings and remarks | **approve their class's offerings and the class** | none | new data: a class-section assignment; see section 6 |
| `HOD`, `HOY` | heads of department / year | their department or year | own offerings | none by default (a school may delegate approval) | none | today treated like a teacher plus `canViewAnyClassData` |
| `TEACHER` | teaching staff | own classes | own offerings: attendance, marks, curriculum progress | none | none | S1: "one of the offering's teachers" |
| `REGISTRAR` | records clerk | register, admissions | register, admissions, student data | none | **no staff grants** (ER-F1) | loses staff routes |
| `ADMISSIONS_OFFICER` | admissions | admissions | admissions | none | none | |
| `TIMETABLER` | timetable | timetable | timetable, rooms, terms | none | none | |
| `FEE_OFFICER` | fee desk | fees | define schedule, issue invoice | none | none | issues; cannot confirm |
| `BURSAR` | finance | fees | reconcile | **confirm payment (from a provider/bank record)**, waive/refund approve | fee policy | the second person for fees |
| `SAFEGUARDING_LEAD`, `PASTORAL_LEAD` | child protection | safeguarding content and audit trail | pastoral notes | none | none | |
| `GUARDIAN` (alias `PARENT`) | computed from the guardian link | **linked children only** | payment **claim**, nothing else | none | none | one name, two aliases today |
| `DEVICE_ATTENDANCE_CAPTURE` | the DPID service audience | none | attendance marks, DPID lookup | none | none | per-school binding (ER-R6) |
| *(service)* `ea-provisioning` | EA | none | create school, first admin | none | first admin only | per-Tenant binding |

Grant rules (ER-R2): SCHOOL_ADMIN may grant any role except to themselves; no one else may grant `SCHOOL_ADMIN`, `HEAD_TEACHER` or `BURSAR`; a REGISTRAR or HEAD_TEACHER may not grant staff roles at all; `FORM_MASTER` is assigned per class by SCHOOL_ADMIN or HEAD_TEACHER.

### 2.4 The approval chain for marks and results, in terms of P3

Creator is not approver at every step; every actor is the token's identity; every step is in an append-only record (marks already are, via `mark_history`).

| Step | Actor | Capability | P3 rule |
|---|---|---|---|
| Enter marks, submit an offering (A3, live on the branch) | a teacher **of that offering** | Enter | n/a (creator) |
| Return or approve the offering (A4) | the **form master of that class** | Approve | must not be one of that offering's teachers; if the form master teaches the subject, the head teacher (or a delegate) approves that offering |
| Ratings and remarks (A4) | form master | Enter | the head teacher's remark is a separate field |
| Approve the class (A4) | form master | Approve | all offerings approved; the approver did not enter any mark on it |
| Release to guardians (A5) | head teacher | Approve (release) | not the class approver, unless the school has one person (the D6-style exception, recorded and flagged) |
| Correct a mark after a lock (A7): request | a teacher of the offering | Enter | creator of the request |
| Correct a mark: decide | form master before release, head teacher after | Approve | approver is not the requester and not the person whose mark changes |
| Freeze at approval (A5) | system | n/a | the frozen computed copy is what release publishes; a later correction creates a new version, never an edit in place |

Consequences for the S1 plan: A4-A7 need an **approve** capability and a **per-class form-master assignment**, which are new predicates/data (section 6). A5's release and A7's decide steps need the second-person rule enforced in the service, not in the screen.

### 2.5 Fees, admissions, staff: the other chains

- **Fees:** FEE_OFFICER defines and issues; **BURSAR confirms or reconciles**, from a provider event or bank record; SCHOOL_ADMIN configures but does not confirm. A guardian's payment becomes a **claim** awaiting verification. Waivers and refunds (open in Epic 13) are approved by a second person.
- **Admissions:** the officer who enters an application is not the person who sets it ENROLLED; enrolment is the approval step (D-ER3).
- **Staff:** per ER-R2.

---

## 3. Use cases

| UC | Actor | Flow | Rule |
|---|---|---|---|
| UC-ER1 | Proprietor / first admin | Gets SCHOOL_ADMIN automatically at registration, then invites staff | first-admin (live); ER-R2 grant cap |
| UC-ER2 | SCHOOL_ADMIN | Grants a REGISTRAR role to a clerk | allowed; cannot be granted by the clerk's peers |
| UC-ER3 | REGISTRAR | Tries to make themselves or a friend SCHOOL_ADMIN | **refused** (`role_not_grantable`) |
| UC-ER4 | Teacher | Enters and submits marks for their offering | Enter; own offering only (A3) |
| UC-ER5 | Form master | Reviews, returns or approves the class | Approve; not on their own subject |
| UC-ER6 | Head teacher | Releases results; approves post-release corrections | Approve; not the class approver unless one-person school |
| UC-ER7 | Fee officer | Issues an invoice | Enter; cannot confirm payment |
| UC-ER8 | Bursar | Confirms a payment from a bank/provider record | Approve; not the issuer of that invoice |
| UC-ER9 | Guardian | Sees only their own children; says "I have paid" | per-child; creates a claim, not a confirmation |
| UC-ER10 | DPID reader | Records attendance at the school it is bound to | per-school service scope |
| UC-ER11 | EA provisioning | Creates a school and its first admin once | per-Tenant scope; never replaces an existing admin |
| UC-ER12 | One-person school | The head does everything | per the platform's D6 exception, recorded and flagged (D-ER1) |

---

## 4. Tasks (dependency-ordered; all need CM's go while the freeze is open)

| # | Task | Closes | Review | S1 interplay |
|---|---|---|---|---|
| **T-ER1** | Closed role list, canonical upper-case, grant cap (ER-R2), last-admin guard on staff routes; one-off normalising migration | ER-F1, ER-F6 | **HIGH** (auth) | none |
| **T-ER2** | Per-child guardian check on `GET /students/{id}` and the other student reads; staff read by role/class | ER-F4 | HIGH | none |
| **T-ER3** | Split the fee predicate: define/issue (FEE_OFFICER) vs confirm/reconcile (BURSAR); issuer ≠ confirmer; guardian "pay" becomes a claim; confirmation only from a provider/bank record | ER-F2, ER-F3 | **HIGH** (money) | coordinate with Epic 13 and the outbox relay (BK-FIN-12) |
| **T-ER4** | Bind the DPID audience to schools (and EA's to Tenants); validate on every call | ER-F5 | HIGH | after the platform's D5 |
| **T-ER5** | Canonical email for guardian matching (trim + lower-case) and record `sub` | ER-F6, R9 | MEDIUM | none |
| **T-ER6** | Approval capability and per-class FORM_MASTER assignment (new predicate/data) for S1 A4-A7, with P3 enforced in the services | the S1 chain in 2.4 | **HIGH** | **blocks A4**; ask CM before writing (section 6) |
| **T-ER7** | `GET /schools/{id}/me` with capability codes and `allowedActions` | R11 / WEB | MEDIUM | needed by WEB for A3+ screens |
| **T-ER8** | Remove the legacy assessment routes (S1 A8) | ER-F7 | HIGH (own gate) | last S1 step |
| **T-ER9** | Refuse to start with a required audience/issuer unset in production mode; test it | R6 | MEDIUM | none |
| **T-ER10** | Split `SCHOOL_ADMIN` per 2.3 (it stops entering grades and money); decide who holds each duty first | ER-F8 | HIGH | needs D-ER2 |
| **T-ER11** | Admissions: enrol requires a second person (or the recorded one-person exception) | ER-F9 | MEDIUM | after D-ER3 |
| **T-ER12** | Audit shape (R10) for staff grants: before/after, actor, `sub` | R10 | MEDIUM | with T-ER1 |

## 5. Order

1. **Now, S1 only on existing predicates:** A1-A3 are done on that basis. Anything new (A4's form master and approval) waits for CM's decision on T-ER6.
2. **First, by risk and by not needing a decision:** T-ER1 (REGISTRAR can make admins), T-ER2 (per-child read), T-ER9, T-ER5.
3. **After Femi's answers D-ER1-D-ER3:** T-ER6 (unblocks A4), then T-ER10, T-ER11.
4. **Money:** T-ER3 with the outbox relay and payment-confirmation design (it must land before any delivery of `StudentPaymentReceived` to SOP).
5. **With the platform's D5:** T-ER4. **Last:** T-ER7 for WEB, T-ER8 (A8) once the S1 screens exist.

## 6. New predicates and data S1 will need (asked of CM, not built)

- **A4:** a per-class **form-master assignment** (data: `class_section_id` → email, per term/year) and an **approve-results** capability (`APPROVE_RESULTS`, in the contract) that is true only for the form master of that class (or the head teacher as fallback).
- **A5:** **release-results** (`RELEASE_RESULTS`), true for HEAD_TEACHER only.
- **A7:** corrections reuse Enter (request) and the two approve capabilities (decide).
- **No** change to existing predicates is proposed for S1; T-ER10 (splitting SCHOOL_ADMIN) would change `canEnterGrades`, `canManageFees` and others and is therefore a separate decision.

## 7. Decisions needed from Femi (school-specific)

- **D-ER1** In a school, who is "the Owner" for P2 and D6: the proprietor (the Tenant's Owner Admin) or the head teacher? Does the creator-may-approve exception apply to a head teacher who also teaches (a very small school), or only to the proprietor?
- **D-ER2** Should `SCHOOL_ADMIN` stop being able to enter grades and run the fee desk (administer only), as D1 implies? The proposal in 2.3 says yes; the cost is that a small school's single admin then needs the other roles assigned to them explicitly.
- **D-ER3** Is enrolment the approval step in admissions, and who approves in a school that has one admissions person?
- **D-ER4** Absent form master: who approves (the head teacher, a named deputy, any HOD)? (Already open in the S1 contract.)
- **D-ER5** DPID credential: one per school or one per Tenant? (Follows the platform's D5.)
- **D-ER6** Guardian "I have paid": acceptable as a **claim** that staff verify, until a provider confirms automatically?
- **D-ER7** Do we keep `PARENT` as an alias of `GUARDIAN` or retire it?

---

## 8. Re-verification of the survey items CM listed

| Survey item | Verdict | Where |
|---|---|---|
| F4: REGISTRAR can grant SCHOOL_ADMIN via `POST /schools/{id}/staff`; free-form roles | **Confirmed**, and worse: the same predicate also lets REGISTRAR demote or revoke an existing admin | `Application.kt:964-985`; `ErPrincipal.canManageRegister` |
| Fee issue and confirm-payment by the same user | **Confirmed**: one predicate guards the whole fee loop, and confirmation is a stub | `Application.kt:645-749`; `FeeService.confirmPaymentStub` |
| (new) A guardian can confirm their own child's invoice | **Confirmed** (ER-F3) | `ParentGatewayService.payInvoice`; `Application.kt:737` |
| `GET student` with any affiliation incl. GUARDIAN, no per-child check | **Confirmed**, with the DTO scope stated precisely (no DOB, medical notes or guardian contacts; but name, class, photo and the safeguarding indicator) | `Application.kt:214`, `StudentDto` at `:1270` |
| DPID device role at any school | **Confirmed**: resolved for whatever `schoolId` is in the URL | `CognitoErIdentityGateway.resolveForSchool` |
| Exact-case role matching | **Confirmed** for roles and guardian links; staff **subjects** are case-insensitive since the first-admin change | `ErPrincipal.hasAnyRole`; `ExposedStaffAssignmentStore` |
| F1 fail-open verifier fall-backs | **Not present in ER**; ER starts quietly with an audience unset (T-ER9) | `CognitoErIdentityGateway`, `AppFactory.identityGateway` |

*Sources: `docs/RBAC_SPUTO.md` v0.2; the Education Runtime code at `origin/master` (route and predicate list extracted from `Application.kt`); `docs/Service_Account_Identity_And_EA_Membership_Design_Note.md`; the S1 contract (`ER/Principal/docs/ER_Assessment_Cycle_S1_Contract_Draft.md`) for sections 2.4 and 6.*
