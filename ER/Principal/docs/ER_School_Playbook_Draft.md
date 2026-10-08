PLAYBOOK CONTENTS (Education Runtime, "EduSys"; per docs/Playbook_Definition.md). Verified against master on 2026-10-08 (assessment set-up, subject offerings and the first-admin route are live; mark entry, S1 step A3, was reviewed and was being released the same day: confirm it is live before relying on the Assessment section). Paths are in the FiSH repo unless noted.

1. Operator sheet: THIS document (below). Written from the code at fish-education-runtime commit 5a890cc, updated after the V31 outbox fix (ER PR #12).
2. Scope (S): ER/Principal/docs/The_Principal_MVP_Definition.md; ER/Principal/docs/Education_Runtime_MVP_Definition.md (floor versus enhancement); ER/Principal/docs/ER_Education_Specialty_Scope.md (what only a school needs, and the specialty-first order); ER/Principal/docs/ER_Terminology_Alignment_SPUTO.md; docs/Fee_Billing_Epic13_SPUTO_Scope.md (cross-service, fees).
3. Plan / SRS (P): ER/Principal/docs/The_Principal_SRS.md; ER/Principal/docs/FiSH-ER-Education-Runtime-Technical-Req-Spec-and-Use-Cases-v0.1.md (the numbered ER-* and FIN-INT-* requirements); DRAFTS, design only: ER/Principal/docs/ER_Assessment_Cycle_S1_Contract_Draft.md (assessment cycle model and API), ER/Principal/docs/ER_Teaching_Staff_Onboarding_ER_Half_Draft.md, ER/Principal/docs/ER_Fee_Billing_Epic13_ER_Half.md, ER/Principal/docs/Education_Runtime_Local_First_Sync_Design.md, ER/Principal/docs/EduSys_Separate_App_SPUTO.md.
4. Use cases (U): the spec's section 8 (UC-01 to UC-14) inside the technical specification above; use cases for the Epic 13 half are in section 3 of its document; WEB's screen-level input for the assessment cycle is in the WEB repo, docs/WEB_Education_Assessment_UX_Input_S1_S2.md. NOT WRITTEN: a stand-alone use-case document for the specialty waves (assessment cycle, report cards, school structure, record depth, safeguarding).
5. Tasks (T): ER/Principal/docs/The_Principal_Backlog.md (the master backlog); ER/Principal/docs/Local_First_Sync_Build_Plan.md (sync tasks 1-7, 1-4 built); section 4 of ER/Principal/docs/ER_Fee_Billing_Epic13_ER_Half.md; section 10 of ER/Principal/docs/ER_Assessment_Cycle_S1_Contract_Draft.md. A finished episode: ER/Principal/docs/Timetabling_And_Lesson_Scheduling_Plan.md.
6. Order (O): section 4 of ER_Education_Specialty_Scope.md (S1 to S8, awaiting Femi's confirmation); section 5 of the Epic 13 half; section 10 of the S1 contract. NOT WRITTEN: one consolidated dependency order across all Education Runtime work (it waits on Femi's choice between the specialty-first order and Epic 13 / staff onboarding).
   Foundations already in place before features (Femi's rule): the outbox column fix (V31), CORS for the web app, the claim-first idempotency ledger and the per-school write lock used by sync. Foundations still to do before the features that need them: real-Postgres tests for every outbox/inbox and money-adjacent path, and a delivery relay for the outbox (nothing delivers events to SOP today).

SCHOOL PLAYBOOK (draft for Omniview's Playbooks tab, industry SCHOOL)

Written by the Education Runtime session, 2026-10-07, from the code as it stands on fish-education-runtime master (commit 5a890cc, PR #9 merged). Updated 2026-10-07 after the outbox fix (V31, ER PR #12) went live: enrolment, payment confirmation and attendance marks failed in production before that fix and are expected to work now; if a school still reports one of them failing, escalate it as a possible new fault rather than assuming the old one. Plain text so it can be pasted straight into the console. Everything below is what the code does TODAY; the last section lists what is NOT built or still being designed, so nobody promises it to a school. Re-check the "verified" date before trusting an answer, and update this when the code changes.

OWNING SERVICE
Education Runtime (repo fish-education-runtime, the backend of The Principal's EduSys). Its owner is the L2 for anything below. Billing identities also touch SOP (Sales Order Processing) and school set-up touches EA (Enterprise Administration).

ESCALATE TO
Lane "education" (L2). Owner and backup: not named yet (Femi names them). Until then the staff alert goes to the support mailbox.

HELP ARTICLES
None written yet. Do not invent links; say so if asked.

HOW ROLES WORK (needed for most "I can't do X" tickets)
A person can only act at a school if a school administrator has given them a role there. Roles are a school-level list, separate from their sign-in. Admissions screens need the admissions role (school admin, registrar or admissions officer). Enrolling a student needs register rights (school admin or registrar): an admissions officer alone cannot enrol. Fees need a fee role (school admin, fee officer or bursar). Timetable needs school admin or timetabler. Marking attendance and entering grades need a teaching role (teacher, head teacher, head of department, head of year) or school admin.
Fact for the operator: someone with no role at a school gets a 403 on everything there, shown as "cross-tenant" (not "forbidden"; "forbidden" means they have a role but not the right one). So "cross-tenant" on every screen in a school usually means they have no role at that school yet. Roles are currently added by a school admin by hand (a person's sign-in email is the key); linking this to HR employment is being designed, not built.
Added 2026-10-08: (1) For a school registered from now on, EA gives the business owner the first school admin role automatically (the owner's sign-in email, lower-cased). Schools registered before that have no admin until the platform team adds one by hand; do not tell a school it can do this itself. The automatic grant happens only while the school has no active admin; it will not replace or add a second admin, and a different email once an admin exists is refused. If the school's only admin was removed, the platform team can run the same grant again for the owner; that is by design. (2) A person's sign-in email is matched ignoring capital letters for school staff, so "Ada@School.org" and "ada@school.org" are the same person. Guardians are still matched exactly, so a parent whose email was recorded with different capitals than they sign in with will see nothing; fix the record, do not change the sign-in. Two rows for the same person differing only in capitals can exist; they are harmless and count as one person. (3) Role names must be exactly the upper-case names (SCHOOL_ADMIN, TEACHER and so on). A role typed as "Teacher" or "school admin" is accepted but grants nothing, with no error: if a person has a role and still gets "forbidden", ask for the exact role text as stored. (4) A school admin is NOT automatically a teacher of anything: to enter marks the person must be one of the teachers named on that subject offering (see Assessment below).

COMMON QUESTIONS AND HOW TO ANSWER

ADMISSIONS

Q: An applicant's status will not move forward / "illegal transition".
A: The pipeline only goes forward one step at a time: Submitted, Under review, Offered, then Accepted or Declined, then Enrolled. You cannot skip a step (for example Submitted straight to Offered) and you cannot go back. Accepted or Declined can only be recorded from Offered. Declined and Enrolled are final. There is no way in the product to reopen or undo a step; if a school entered something wrong, escalate (an engineer has to correct it).

Q: "Duplicate enrolment: applicant X already has ..." when submitting.
A: A school can hold only ONE application per applicant reference per academic year, whatever its status, including Declined and Enrolled. So a declined applicant cannot re-apply for the same academic year under the same reference. Check whether an application already exists (the Admissions list shows every status). If the school genuinely needs a second try for the same year, escalate; do not suggest a different reference as a workaround without telling the school it creates a second record.

Q: "Enrol requires register rights" (or forbidden) when moving to Enrolled.
A: Enrolling writes to the student register, so the person needs school admin or registrar. An admissions officer can take an application up to Accepted but not enrol it. Ask a school admin or registrar to do the final step, or have an admin give the person the registrar role.

Q: Where is the offer letter?
A: Moving to Offered stores a reference number only (it looks like OFFER-<application id>-<date>). No letter or PDF is generated. Schools write their own letter and quote the reference. Do not promise generated letters.

Q: Document checklist.
A: The application can hold a checklist, but it is stored as plain text for the school's own use; nothing checks or enforces it and nothing blocks enrolment on it.

Q: What happens when someone is enrolled?
A: A student record is created on the register (or, if a student with the same applicant reference already exists, that record is updated with the class). The new record has the name and class from the application only: no date of birth, guardians or medical notes. The school fills those in afterwards. An "enrolled" event is recorded for the billing side (see the fees note below on what that does and does not do).

Q: Can parents see or accept an offer themselves?
A: No. Office staff record what the guardian told them (the decision, optionally how: phone, email, in person). The parent view only works after enrolment.

GUARDIAN FEE BILLING

Q: "Email or phone required to resolve a guardian account".
A: A guardian account is found or created by school plus email or phone. The Guardians list therefore shows every guardian account set up, which can include one with no invoice yet. At least one of the two is required, plus a name. A guardian with two children at the school reuses the same account when the email or phone matches.

Q: "This school is not yet linked to an institution ... cannot bill a guardian until EA provisioning completes".
A: The school was not created through the normal school set-up, so it has no link to the business that bills. This is not something the school can fix. Escalate to the Education Runtime owner and EA (the link is made when the business is set up as a school). Older schools set up before that flow are the likely cause.

Q: "SOP customer creation failed" or "SOP customer gateway not configured".
A: When a guardian account is set up (the "resolve guardian" step, which comes BEFORE issuing an invoice and is a separate action), the product creates a customer record in Sales Order Processing the first time that guardian has none. Issuing an invoice does not itself create a customer; an invoice can even be issued with no guardian attached. If the customer creation fails, the guardian account cannot be used to bill. Retry once; if it persists, escalate with the full message. "Not configured" is a deployment problem, escalate immediately. Added 2026-10-08: before that date this step failed EVERY time, whatever the school did: the Education Runtime was calling a Sales Order Processing address that SOP had removed on 2026-09-30, and it also could not read SOP's reply. That is fixed (ER branch fix/sop-customer-company-path, released 2026-10-08). So a failure from this step reported before the release is explained; one reported after it is not. If it fails after the release, collect the exact message and escalate; do not blame the school. The two usual real causes now: the school is not linked to a business (see the previous answer), or SOP refused the request (the message then carries SOP's own code, for example invalid_customer).

Q: "Duplicate invoice for student+cycle+schedule".
A: One invoice per student, per billing cycle, per fee item. The first one already exists; look in the invoice list rather than issuing again.

Q: A fee item will not save.
A: The amount must be a positive decimal such as 15000.00 and the currency a three-letter code (the default is NGN). The code is turned to upper case; saving an existing code updates it.

Q: The parent says they paid; can we mark it paid?
A: Fee staff (or a linked guardian through the parent view) can confirm payment on an invoice, with a method such as cash or transfer. IMPORTANT, say this plainly: there is no payment provider connected. "Confirm payment" only records that the school says it was paid; no money moves through the product. An already paid invoice cannot be confirmed again ("invoice already paid").

Q: The invoice shows paid, but the school's books / ledger do not show the money. Or: has the enrolment reached the accounts?
A: Be careful here. Marking an invoice paid, and enrolling a student, each record an event in the Education Runtime's own outbox for the billing side. As of 2026-10-07 I found nothing in the Education Runtime or in SOP that delivers those events onward, so they should be treated as NOT posted to the ledger. Do not tell a school its payment or enrolment has reached its accounts. Escalate with the invoice number and ask the owner to confirm the current state. (If an invoice was left open by a crash after its event was recorded, a "reconcile" action exists for fee staff and flips it to paid only when the event really exists.)

TIMETABLING

Q: "Timetable conflict" when saving a lesson.
A: The same teacher, class section or room is already booked in an overlapping time on that weekday. The message names who and when (for example "Teacher T already assigned 09:00-10:00 on MONDAY"). Lessons repeat weekly on a day and time range; end must be after start. Fix the clash or move one lesson.

Q: "Teacher ... is not assigned to teach ..." or "unknown room".
A: Timetablers can only schedule a teacher for a subject the teacher has been assigned (subject assignments are set per teacher) and only into a room that exists in the school's room list. A school admin can bypass both checks. Fix by adding the subject assignment or the room first; do not ask the school to "just retry".

Q: Can I see or delete a lesson?
A: The timetable lists every lesson for the school, and a lesson can be deleted by id. Lessons can optionally be tied to a term; terms (academic periods) have a year, number, start and end date.

Q: A teacher only sees some classes / no classes on the register.
A: For class rosters, plain teachers see only classes where they have a timetabled lesson; heads (head teacher, head of department, head of year) and admins see all. If a new teacher sees nothing, they either have no timetabled lesson yet or no role at the school (see roles above).

ASSESSMENT: SET-UP, SUBJECT OFFERINGS AND MARK ENTRY (added 2026-10-08; step A3, mark entry, was being released the same day)
Say this first: these are server features only. The web app has no screens for them yet (the screens are being designed by the web team), so a school cannot do any of this on its own today. Do not promise screens, report cards or results for parents; none exist. The older "assessments" actions (define a structure, enter a grade, publish a grade set) still exist and are a different, simpler thing that is being replaced; a ticket that mentions "publish" is about the old one.

Q: Who can set up grading scales, score structures and subject offerings?
A: School admins only. Teachers can look at scales and structures but not change them. Parents and other roles see nothing.

Q: What is a grading scale?
A: A list of bands, each starting at a score. The first band must start at 0; each band runs up to where the next one starts; the last runs to 100. There is no built-in national scale: the school supplies its own. Saving a scale again with the same id replaces it, UNLESS a score structure already uses it ("scale_in_use"): then create a new scale instead. Messages "invalid_scale" mean the bands are out of order, do not start at 0, or a grade or remark is too long.

Q: What is a score structure, and why won't mine save?
A: It says, for one level and term, which parts make up a subject's total (for example class work out of 40 and exam out of 60), how much each part is worth, how many decimals a mark may have (0 to 2), whether positions are shown, what an absent or excused student counts as, and which grading scale to use. The weights must add up to exactly 100: "weights_not_100" says what they do add up to. By default an ABSENT mark counts as zero and an EXCUSED mark is left out of the total; the school can choose the other way for each. Once any mark has been entered against a structure it can no longer be changed ("structure_in_use"): create a new structure (a new id) for the next term. A structure also keeps the level and term it was created with ("structure_identity_fixed").

Q: What is a subject offering and why won't it save?
A: One subject taught to one class section in one term: it names the teacher or teachers (up to ten), the structure and an optional deadline. The term comes from the structure. "duplicate_offering": the class already has that subject for that term. "unknown_teacher": the person is not an active member of staff with a teaching role at this school; add their role first. "unknown_class_section" or "unknown_structure": the id does not exist at this school. After marks exist, the class, subject and structure can no longer change ("offering_in_use"), but teachers and the deadline can. After the teacher submits it cannot be edited at all ("offering_locked").

Q: A teacher gets "not_your_offering" (403).
A: Marks can be entered, and an offering submitted, only by one of the teachers named on that offering. This applies to a school admin too: an admin who wants to enter marks must be named as a teacher on the offering. Add the person to the offering (admin only), do not give them a bigger role.

Q: How does a teacher enter a mark, and what is "not entered"?
A: One mark is one student, one part of the structure (for example "CA"). It is a number within that part's maximum, or a code: ABSENT (did not sit) or EXCUSED. Taking a mark back to "not entered" (the typing-mistake case) is different from ABSENT, and nothing is shown as zero unless it was entered as zero. After each save the reply carries that student's total, grade and, if positions are on, their position, so the screen can update without reloading the list.

Q: "stale_mark".
A: Someone else (or the teacher on another phone) changed that mark since this person last looked. The reply gives the current value and version. They should look at the current value and enter again; nothing was lost, and nothing of theirs was saved over it. Every change needs the version the person last saw; a first entry on an empty mark needs none.

Q: "out_of_range", "too_many_decimals", "student_not_in_class", "unknown_component".
A: The mark is above the part's maximum (the reply gives the maximum) or below zero; it has more decimals than this structure allows (the reply gives how many); the student is not in this class; or the part name is not in this structure. All are fixable by the teacher; none is a fault.

Q: "locked" or "past_deadline". Can the teacher change a mark after submitting?
A: No. Once an offering is submitted it is read-only. There is NO way to send it back yet: the form master's review, return and approval are not built. Escalate with the offering; do not suggest workarounds. The deadline is compared with the time the server receives the mark, not the time the teacher typed it. A teacher who entered marks offline before the deadline and syncs after it will be refused. How to treat that is an open decision; escalate such cases and say so.

Q: Why is a student's total blank?
A: A total only appears once every part has been entered (or coded). A student with a part still not entered, or whose every part is excused or left out, has no total, no grade and no position. That is correct, not a fault. Totals are out of 100. Positions run 1, 2, 2, 4 for ties and say "tied"; a structure can switch positions off.

Q: The phone lost signal and sent the same mark again.
A: Safe. Every mark carries a unique operation id; the same one sent again returns the saved mark and does not save twice, even if the offering has been submitted since. "op_in_progress": the first send is still being processed; try again in a moment. "op_id_reused": the same operation id arrived with a different mark, which means a fault in the app: escalate.

Q: Can the teacher submit with marks missing?
A: Submitting normally refuses ("gaps_present") and says how many are missing for each part. The teacher can choose to submit with gaps. Submitting locks the offering for everyone.

Q: Who can see the list of students and marks, and who can see who changed what?
A: The list (with names, marks, totals) is for the offering's teachers and the school admin. The full history of every change to a mark (before, after, who, when, which operation) is school admin only. It is kept permanently and the database refuses any edit or delete of it. If a school disputes a grade, the history is the evidence: collect the student, subject, part and term and escalate.

Q: Has anything reached the parents?
A: No. Approval by the form master, release by the head teacher, report cards and corrections after release are not built. Parents see nothing of this.

ATTENDANCE (short; the full register is still being designed)
Q: How does attendance work today?
A: A teacher marks one student at a time with a code (present, late, unexplained, illness, medical, authorised other, educational visit, off site, excluded). Marking the same student and day again REPLACES the earlier mark; there is no history of the earlier code yet. Card-reader (DPID) marks come in separately per lesson. A page for taking a whole class register is not built yet.

NOT BUILT, OR STILL BEING DESIGNED (do not promise these)
- Online payment collection (no payment provider).
- Generated offer letters, mail-merge or document storage.
- Whole-class attendance register screen, attendance reports and percentages, correction history, school time zone for reader marks.
- Posting school fees and enrolments to the ledger automatically (see the fees answer above).
- Onboarding teachers from HR automatically; staff roles are added by hand today.
- The offline phone app for teachers (the server side exists; there is no client yet).
- Reopening or undoing an admissions step.
- Anything after a teacher submits marks: the form master's review, return and approval, ratings and remarks, release to parents, report cards, corrections after a lock. Screens for set-up and mark entry. A rule for marks entered offline and synced after the deadline.
- School admins choosing roles per person beyond the fixed list is not controlled yet: a person who can manage staff can currently give any role, including school admin. This is a known weakness being fixed (see the Education Runtime RBAC plan, docs/ER_RBAC_SPUTO.md); do not rely on it as a control.

BEFORE ESCALATING, COLLECT
The school name, the person's sign-in email and their role at that school, the exact message shown, the applicant reference or invoice number, and the time it happened.
