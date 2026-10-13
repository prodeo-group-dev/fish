# Education Runtime Playbook, part 3 of 4: Use cases (U)

**Status:** DRAFT, 2026-10-13, planning only; nothing is built before Femi approves the whole Playbook (parts 1 to 4 together). Parts 1 and 2 are `docs/ER_Playbook_1_Scope.md` and `docs/ER_Playbook_2_SRS.md`. Written by the Education Runtime (+ER) session. Evidence tags as before: **[code]** read in `fish-education-runtime` on 2026-10-13, **[decided]** recorded Femi decision, **[TBC]** unverified or undecided.

**What these are.** Sixteen use cases that together run a school term, each written so it can be used as a **UAT script**: who, what must already be true, the main flow, the alternate and error flows, which Part 2 requirements it proves, and what the offline behaviour is. The error flows use the real refusals the code gives today where they exist (named in backticks) and say "new" where the refusal does not exist yet. Screens are WEB's; this part says what the person does and sees, not how it looks. Words are the school vocabulary (`School_Vocabulary_For_WEB.md`).

**Acceptance link.** Part 2 section 9 criterion 1 says every P1 requirement is demonstrated by these scripts on a low-cost Android device. The coverage index at the end maps each P1 requirement to a use case.

## Actors

Business Owner, head teacher, **school admin**, registrar, admissions officer, teacher (including form master, head of department, head of year), timetabler, bursar, fee officer, safeguarding lead, pastoral lead, guardian, and two systems: the **device account** (attendance reader) and **SOP** (money). A person holding two roles has both rights (an admin who also teaches can enter marks).

---

## UC-E1 Set up a new school

**Actors:** Business Owner; school admin; EA (system). **Reqs:** PL-SET-1, 2, 3, 5.
**Pre:** the Business Owner has registered a Company as a school (industry type school) in EA.
**Main flow**
1. EA provisions the school in the Education Runtime (school id, organisation id) and sets the first admin.
2. The first admin signs in and sees an empty school with a hint: "No teachers, registrar or bursar yet: add staff and roles."
3. The admin opens **Staff and roles**, adds each person with a role (registrar, bursar, teachers, timetabler). A person must exist in the platform; a role is a school-level grant.
4. The admin configures the school: academic year and terms, levels and arms, subjects, grading scale and score structure, fee schedule items (each with a Finance-set VAT category), positions on or off.
5. The admin registers devices for attendance (UC-E15).
**Alternates / errors**
- A person without any role at the school gets a refusal shown as *cross-tenant* on every screen; with a role but not the right one, `forbidden`. [code]
- Removing the **last admin** is refused (`last_admin`); a registrar cannot make or remove admins (`role_not_grantable`); an unknown role is `unknown_role`. [code]
- Until a teacher or bursar role exists, **nobody can enter marks or raise invoices** (the admin alone cannot) [decided]: the hint in step 2 and the Staff-and-roles screen are what prevent a dead end. **New:** the screen.
- A fee item with no VAT category is refused at save. **New.**
**Offline:** not applicable (set-up is online).

## UC-E2 Admit and enrol a student

**Actors:** admissions officer, registrar or admin, head teacher (offer decision, configurable), guardian (applicant side), EA/SOP (billing identity). **Reqs:** PL-ADM-1 to 5, PL-ENR-1 to 5, PL-CON-1, 3, PL-FEE-5.
**Pre:** a school with arms and at least one fee schedule item.
**Main flow**
1. An application is created (applicant reference, names, intended level, academic year, guardian contact).
2. The pipeline moves one step at a time: Submitted, Under review, Offered (an offer reference and, in P1, a generated letter stored as a document), Accepted or Declined, then **Enrolled**.
3. Enrolment (registrar or admin) creates the student on the register in the chosen arm, generates the admission number, and warns on a possible duplicate (name, date of birth, guardian phone).
4. The guardian account is created or found, and linked to a SOP Customer (idempotently); the student's fee schedule applies.
5. The registrar completes bio-data and the health summary; a photograph is captured with consent.
**Alternates / errors**
- Skipping a step or going back: `illegal transition`. One application per applicant reference per academic year, any status, so a declined applicant cannot re-apply that year under the same reference (`Duplicate enrolment`). [code]
- Admissions officer can take an application to Accepted but not enrol (`Enrol requires register rights`). [code]
- SOP refuses (billing not switched on for this school): `billing_not_enabled`; SOP unavailable: `billing_unavailable`; the guardian account stays and the same request works later. [code]
- Duplicate student by name, date of birth and phone: a warning the registrar can override with a reason. **New.**
**Offline:** capture works offline; the duplicate check and the SOP link run on sync.

## UC-E3 Maintain student and contact records

**Actors:** registrar, admin (read; writes until a registrar exists [decided]), head teacher, teacher (own classes). **Reqs:** PL-ENR-3 to 9, PL-CON-1 to 6, PL-PRV-1.
**Main flow**
1. A registrar opens a student, edits bio-data, adds a second contact, sets the emergency order, records a custody status and the fee payer.
2. A court order or contact restriction is recorded on a contact: a prominent warning appears for staff; the detail is visible only to the safeguarding lead and head teacher; release of information and pickup are blocked.
3. A class transfer is recorded with date and reason; the effective-dated history shows previous values, who changed them and when.
4. A CSV of students is imported with a preview, a dry run and an error report; an export is produced and **logged**.
**Alternates / errors**
- A teacher opens a student outside their classes: the roster is scoped to assigned lessons; the student read is allowed but restricted fields are masked. [code]
- A guardian-only caller reads only their own linked child; another child answers exactly as a missing one (`not found`). [code]
- An import row fails validation: the error report names row and field; nothing is partly applied. [code: CSV import exists]
**Offline:** lookup read-only offline; edits queue and sync (last writer wins for contacts, previous value kept).

## UC-E4 Take the daily register (offline) and correct it

**Actors:** teacher, form master, device account. **Reqs:** PL-ATT-1 to 9, PL-CLS-3, PL-SET-7.
**Pre:** the teacher's phone is a registered device; the arm and lessons exist; the form master is assigned to the arm.
**Main flow**
1. The teacher opens the register for an arm with no connection; the roster is already on the device.
2. Marks are entered with the status code (present, absent, late, excused, sick, exeat) and time of arrival for late.
3. The device stores the marks and shows a sync queue; on connection it pushes them; the server applies each exactly once (a replay of the same operation returns the recorded outcome).
4. The form master sees unexplained absences and approves the register (or delegates).
5. Guardians of unexplained absentees receive a same-day SMS with no sensitive detail (UC-E12); chronic and consecutive absence alerts go to the form master and head of year.
6. A reader at the gate posts a mark through the device account.
**Alternates / errors**
- A mark for a student not in the arm, a closed period or an unregistered/revoked device is refused (`forbidden`); the queue keeps the rejected item visible. [code: device rules]
- A correction needs a **reason**; the original mark and audit stay. **New.** Replace-on-remark exists today. [code]
- The school admin alone cannot take attendance [decided]; an admin who also teaches can.
- Late sync beyond the school's deadline is flagged for review, not dropped (**D4**).
**Offline:** the whole use case works for days offline; clock integrity is checked and server time is recorded at sync.

## UC-E5 Enter a term's marks, submit, approve and lock

**Actors:** teacher (subject), head of department, head teacher; approvers per **D3**. **Reqs:** PL-ASM-1 to 4, 11.
**Pre:** grading scale and score structure set; a subject offering links an arm, subject, term and teachers.
**Main flow**
1. The teacher opens "my offerings", picks one, and enters CA and exam scores per student, offline or online; each cell keeps a version and history.
2. The roster view pages through students, can filter to missing marks, and shows a total per student as scores are entered.
3. The teacher submits; if any mark is missing the teacher confirms "submit with gaps".
4. The approver (per the configured chain) reviews, approves or returns with a comment; on approval the marks are **locked**.
5. A change after locking needs an approval and is audited.
**Alternates / errors**
- A teacher who does not teach this offering: `not_your_offering`. The admin alone or the bursar: `forbidden` (the same 403 body as any unauthorised role). [code]
- A score outside the structure's range: refused with the field; an absent or excused mark follows the structure's rule. [code]
- A retried mark entry with the same operation id returns the first outcome and writes once; a stale version is refused with the current value (**conflict**), never overwritten. [code]
- Returning for correction re-opens only that offering. **New.**
**Offline:** mark entry works offline; submit and approval are online.

## UC-E6 Report cards, broadsheets and promotion

**Actors:** teacher (comments), form master, head teacher; guardian (reader). **Reqs:** PL-ASM-5 to 9, PL-RPT-3.
**Main flow**
1. After all offerings for an arm are locked, the system computes totals, averages, subject and class positions (if enabled), and highest, lowest and average per subject.
2. The form master adds affective and psychomotor ratings and a comment; the head teacher adds a comment.
3. Report cards are generated per student from the school's template (PDF), with attendance, ratings, next-term date and, if configured, a fee line; a broadsheet per arm is generated.
4. The head teacher publishes; guardians are notified by SMS with a secure link.
5. At session end, the promotion run proposes promote, repeat or probation by the configured criteria; the head teacher approves; guardians are notified; the new session's class lists are produced after a **preview** that can be reversed.
**Alternates / errors**
- Publishing with an offering not locked is refused naming the offering. **New.**
- Clearance: a school that configured a clearance policy **withholds the printed card for unpaid fees** only if **D8** allows it; attendance, safeguarding and medical information are never blocked.
- Positions off: the card omits positions.
**Offline:** none; this is online.

## UC-E7 Raise a term's fees and record a verified payment (through SOP)

**Actors:** bursar or fee officer, guardian, SOP. **Reqs:** PL-FEE-1 to 9, 13, PL-CON-3.
**Pre:** fee schedule items with VAT categories; students enrolled; guardian accounts linked to SOP Customers; the school's Company is allowed at SOP (EA says it is a school).
**Main flow**
1. The bursar runs the term's billing: for each student the schedule applies; ER raises a credit sale in SOP with key `ER-invoice-{id}`, lines carrying the VAT category, term dates and the student reference, and "raised by" set to the bursar.
2. ER stores only the mapping (invoice id, student, SOP sale id).
3. A guardian pays by bank transfer or at the desk; the **fee desk verifies** the payment; ER records the collection in SOP with key `ER-payment-{id}`; SOP numbers the receipt; the cash account is the Company's cash book.
4. The statement for a student and the outstanding per guardian read through SOP; a defaulter list shows what is outstanding (older than 30 days labelled).
**Alternates / errors**
- SOP not enabled for the school: `billing_not_enabled`. SOP or EA unavailable: `billing_unavailable`, retry safely; the same key converges to one sale or one collection. [code for the refusal codes]
- A **parent's tick "paid" is a claim**: it triggers verification and never calls SOP (T-ER3, held). [decided]
- The admin alone cannot raise or record (`forbidden`); the admin reads. A missing VAT category refuses the invoice. [decided; new]
- A retry after a timeout never makes a second invoice (idempotent key). **New with the SOP key.**
- Over-the-term revenue recognition is a Finance decision (**D6**); first build raises at term start.
**Offline:** raising and verifying are online only; a cash receipt at the desk is provisional until synced (P2, PL-FEE-11).

## UC-E8 A guardian sees their child and pays

**Actors:** guardian (phone sign-in). **Reqs:** PL-PRT-1 to 3, PL-CON-5.
**Main flow**
1. The guardian signs in (phone and one-time code, P1 platform change) and sees their linked children.
2. For each child: published results and report card, attendance summary, timetable, fee statement and invoices, notices.
3. The guardian marks an invoice as paid and uploads or quotes the reference; it appears to the bursar as a claim to verify; after verification the invoice shows paid.
**Alternates / errors**
- Another family's child answers exactly like a missing child. A guardian-only principal cannot read staff routes. [code]
- A restricted contact (court order) never sees the restricted child's information or pickup. **New.**
- Low data: pages are small; results summary also by SMS for non-smartphones (P2).
**Offline:** a guardian's own phone: read what is cached.

## UC-E9 Record a safeguarding concern

**Actors:** any staff member raising; safeguarding lead and head teacher (restricted); pastoral lead. **Reqs:** PL-SAF-1 to 3, PL-STF-4.
**Main flow**
1. A teacher raises a concern: a short note with a category; it is stored restricted; other staff see only a marker "speak to the safeguarding lead".
2. The safeguarding lead opens it (the access is **logged**), records actions and referral steps with timestamps, and escalates.
3. Alerts for safeguarding go only to the safeguarding group.
**Alternates / errors**
- Anyone else opening it: refused, and the attempt is logged. A safeguarding detail is **never** in an SMS or exported without a logged reason. [code for notes, flag, masking, access log; new for workflow]
- **The admin alone does not see safeguarding records by default** (C2, **Femi's decision**); break-glass needs a reason, is time-limited and alerts the group.
**Offline:** notes queue on the device and sync; the restricted flag applies as soon as synced.

## UC-E10 Manage a teacher's record (employ once)

**Actors:** admin or head teacher; HR; EA. **Reqs:** PL-STF-1 to 6.
**Main flow**
1. A new teacher is employed once in HR (employment, contact) and given platform access by EA; the Education Runtime is told by reference.
2. The head teacher or admin completes the **teaching record**: subjects, arms, registration (with expiry), vetting checks, child-protection training.
3. A report shows missing or expired items; reminders go out before expiry (P2).
**Alternates / errors**
- A person with no HR record cannot be given a teaching record (the HR link is required). **New.**
- Vetting detail is visible to the head teacher, the safeguarding lead and the admin; not to other teachers. [decided; gated]

## UC-E11 Give, change and remove roles

**Actors:** school admin (and the Business Owner). **Reqs:** PL-SET-3, 5.
**Main flow:** the admin opens Staff and roles, grants or revokes roles; a termly access-review report lists everyone with their roles; a leaver is removed promptly.
**Alternates / errors:** `role_not_grantable` (only an admin makes or removes an admin), `last_admin` (cannot remove the last), `unknown_role`; removing a role takes effect on the person's next request. [code]

## UC-E12 Message guardians

**Actors:** form master, bursar, head teacher; the messaging gateway. **Reqs:** PL-NOT-1 to 4, PL-CON-2, 7.
**Main flow:** a staff member selects a template (absence, fee reminder, results ready, notice), a group (by arm, level, fee status) and sends; each message goes to the guardian's preferred channel and language; delivery status and cost are tracked.
**Alternates / errors:** a guardian who opted out of non-essential messages is skipped; a message containing health or safeguarding detail is **refused at compose**; SMS fails, then the failure is shown and, in P2, WhatsApp falls back to SMS; a bulk send above the threshold needs approval (P2). **New** (no messaging exists).
**Offline:** composing queues; sending is online.

## UC-E13 Run reports and exports

**Actors:** head teacher, admin, registrar, bursar, teacher (own classes). **Reqs:** PL-RPT-1 to 4, PL-IMP-1, 2.
**Main flow:** search a student by name, admission number or guardian phone; run class lists, broadsheets, attendance and fee reports; export to PDF, CSV or Excel; **every export is logged** with who, what and when, and applies the same field restrictions as on screen.
**Alternates / errors:** a role without the field cannot export it; a large export runs in the background; a bulk operation shows a preview and can be reversed (promotion, arm reassignment).

## UC-E14 Handle a data-subject request and a retention review

**Actors:** admin, head teacher (controller's delegate). **Reqs:** PL-PRV-1 to 4.
**Main flow:** a guardian asks for their child's data; the admin records the request, gathers the data, responds within the country's deadline; at year end a disposal review lists records past retention; the head teacher approves disposal; consent withdrawals are honoured and logged.
**Alternates / errors:** an erasure request on a record under legal retention is refused with the legal basis recorded.

## UC-E15 Register or revoke a device

**Actors:** admin. **Reqs:** PL-SET-7, PL-ATT-2.
**Main flow:** the admin registers a teacher's phone as a device for offline use (a device id is bound to the person); a lost phone is revoked at once; the next sync from it is refused (`forbidden`); remote wipe of the offline store is requested (P1 target).
**Alternates / errors:** an unregistered or revoked device cannot sync marks or attendance; the person can still use the online app. [code]

## UC-E16 Term end and the next term

**Actors:** head teacher, registrar, bursar. **Reqs:** PL-ASM-9, PL-IMP-1, PL-FEE-2.
**Main flow:** promotion (UC-E6), arm reassignment by bulk operation with preview, new term opened, the next term's billing run (UC-E7), guardians notified; leavers are graduated with transfer letters and certificates (P2).
**Alternates / errors:** a bulk step that fails midway is reversible; no invoices are raised for withdrawn students.

---

## Phase 2 use cases (named now so the model leaves room; scripts written when scheduled)

External exam registration and CA export (PL-EXM); boarding: exeat, sick bay, roll call (PL-BRD); gate and visitor log and pickup verification (PL-SAF-4, 5); incident reporting with escalation (PL-SAF-3); suspensions and expulsions; offline cash receipting (PL-FEE-11); WhatsApp messaging; statutory returns per country (PL-RPT-5); group dashboards (PL-RPT-6).

## Coverage index: P1 requirements to use cases

| Area | Requirements | Use cases |
|---|---|---|
| Admissions, enrolment | PL-ADM-1 to 5, PL-ENR-1 to 5, 8 | UC-E2 |
| Student records, import | PL-ENR-6, 7(P2), 9, PL-IMP-1, 2 | UC-E3, UC-E13, UC-E16 |
| Contacts | PL-CON-1 to 3, 5, 6 | UC-E2, UC-E3 |
| Staff | PL-STF-1 to 5 | UC-E10 |
| Structure, form master | PL-CLS-1 to 4, 6, 7 | UC-E1, UC-E4 |
| Attendance | PL-ATT-1 to 3, 5 to 9 | UC-E4 |
| Assessment | PL-ASM-1 to 9, 11 | UC-E5, UC-E6, UC-E16 |
| Fees | PL-FEE-1 to 9, 13 | UC-E7, UC-E8 |
| Messaging | PL-NOT-1 to 4 | UC-E12, UC-E4, UC-E6 |
| Documents | PL-DOC-1, 2, PL-ADM-3 | UC-E2 |
| Safeguarding | PL-SAF-1, 2 | UC-E9 |
| Reports | PL-RPT-1, 3, 4 | UC-E13 |
| Portal | PL-PRT-1 to 3 | UC-E8 |
| Set-up, roles, devices, privacy, audit | PL-SET-1 to 3, 5, 7, PL-PRV-1 to 4, 6, PL-AUD-1 | UC-E1, UC-E11, UC-E14, UC-E15 |

## Next

Part 4 (Tasks and Order): the dependency-ordered task list with sizes and the safety foundations first (idempotency, concurrency, fail-closed configuration), each task naming the use cases and requirements it delivers, the CM gate it needs, and the consolidated decision list for Femi.
