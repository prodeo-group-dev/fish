SCHOOL PLAYBOOK (draft for Omniview's Playbooks tab, industry SCHOOL)

Written by the Education Runtime session, 2026-10-07, from the code as it stands on fish-education-runtime master (commit 5a890cc, PR #9 merged). Plain text so it can be pasted straight into the console. Everything below is what the code does TODAY; the last section lists what is NOT built or still being designed, so nobody promises it to a school. Re-check the "verified" date before trusting an answer, and update this when the code changes.

OWNING SERVICE
Education Runtime (repo fish-education-runtime, the backend of The Principal's EduSys). Its owner is the L2 for anything below. Billing identities also touch SOP (Sales Order Processing) and school set-up touches EA (Enterprise Administration).

ESCALATE TO
Lane "education" (L2). Owner and backup: not named yet (Femi names them). Until then the staff alert goes to the support mailbox.

HELP ARTICLES
None written yet. Do not invent links; say so if asked.

HOW ROLES WORK (needed for most "I can't do X" tickets)
A person can only act at a school if a school administrator has given them a role there. Roles are a school-level list, separate from their sign-in. Admissions screens need the admissions role (school admin, registrar or admissions officer). Enrolling a student needs register rights (school admin or registrar): an admissions officer alone cannot enrol. Fees need a fee role (school admin, fee officer or bursar). Timetable needs school admin or timetabler. Marking attendance and entering grades need a teaching role (teacher, head teacher, head of department, head of year) or school admin.
Fact for the operator: someone with no role at a school gets a 403 on everything there, shown as "cross-tenant" (not "forbidden"; "forbidden" means they have a role but not the right one). So "cross-tenant" on every screen in a school usually means they have no role at that school yet. Roles are currently added by a school admin by hand (a person's sign-in email is the key); linking this to HR employment is being designed, not built.

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
A: When a guardian account is set up (the "resolve guardian" step, which comes BEFORE issuing an invoice and is a separate action), the product creates a customer record in Sales Order Processing the first time that guardian has none. Issuing an invoice does not itself create a customer; an invoice can even be issued with no guardian attached. If the customer creation fails, the guardian account cannot be used to bill. Retry once; if it persists, escalate with the full message. "Not configured" is a deployment problem, escalate immediately.

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

BEFORE ESCALATING, COLLECT
The school name, the person's sign-in email and their role at that school, the exact message shown, the applicant reference or invoice number, and the time it happened.
