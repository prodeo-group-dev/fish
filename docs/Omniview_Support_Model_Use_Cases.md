# Omniview Support Model: Use Cases

**SPUTO, step U.** Companions: `docs/Omniview_Support_Model_SRS.md` (requirements `FR-SUP-*`,
decisions `SD1`-`SD13`), `docs/Omniview_Support_Model_Backlog.md`. Planning only, 2026-10-05.

Every use case ends with the **completeness check** (Femi's rule, FR-OV-S32): who is told, what happens
if nobody acts, how it closes. **Actors:** Owner Admin (the tenant's only ticket raiser), Staff (a tenant
user without that right), Operator (Prodeo L1), Specialist (L3: tax, accounting, security, education
owner), Engineer (L2: the service owner), Femi (owner and, for now, on-call).
UC-OV-5 and UC-OV-6 (raise and answer a ticket) are the v1 core and are not repeated.

## Case handling

### UC-SUP-1: Triage a new ticket
**Actor:** Operator. **Trigger:** the alert for a new ticket, or the unassigned queue.
1. The operator opens the ticket; the **tenant card** (UC-SUP-2) loads beside the thread.
2. They set the **family** (from the catalogue) and **severity** (P1 to P4), with a reason when it is P1 or P2.
3. Routing proposes a lane and an owner; the operator accepts or changes it and takes the ticket.
4. The SLA clock starts for the severity; a first reply is sent, from a **macro** if one fits.

**Alternates.** 2a. The Owner Admin's words describe a P1 (cannot post, compromise, outage): raise to P1,
alert the on-call at once (UC-SUP-9). 3a. No lane matches: it goes to the general lane and the gap is
noted for routing. **Completeness.** *Told:* the owner of the lane, by alert. *If nobody acts:* the
unassigned ticket ages in a visible queue and the SLA alert fires at half the target and at breach.
*Closes:* the ticket leaves "unassigned" the moment an owner takes it.

### UC-SUP-2: Open the tenant card
**Actor:** Operator or Specialist. **Trigger:** working a ticket, or searching for a tenant.
1. Omniview assembles the card from **read-only** calls (FR-SUP-B2): status, verification and deadline,
   Owner Admin, each Company (jurisdiction, currency, industry, modules, staff counts per role), plan
   state (when it exists), open and recent tickets, active incidents touching the tenant, onboarding progress.
2. Each field names its source and age; a source that is slow or down shows "unavailable" and the card
   still renders (NFR-SUP-5).
3. The open is **logged** against the operator (FR-SUP-F4).

**Alternates.** 1a. A tenant with many Companies: the card shows the ticket's Company first and collapses
the rest. 1b. No business data appears (FR-SUP-B4). **Completeness.** *Told:* nobody needs to be; the
access log is reviewed by Femi. *If nobody acts:* nothing pending. *Closes:* immediately; the log line is permanent.

### UC-SUP-3: Escalate to a service owner or a specialist
**Actor:** Operator. **Trigger:** a fault the operator cannot resolve (family 6), a tax or close judgement (7, 8), a security concern (10).
1. The operator writes a **handoff note** (what was asked, what was tried, the Company and request ids).
2. The ticket's owner becomes the L2 or L3 lane; the Owner Admin sees one thread and a plain "a specialist is looking at this".
3. The specialist replies in the same thread, or returns it to L1 with notes.

**Alternates.** 1a. A professional judgement is needed: the specialist replies with the product explanation
and offers a Prodeo Capital engagement (SD4). 2a. The cause is a defect: link or create a **problem record** (UC-SUP-10).
**Completeness.** *Told:* the lane's owner, by alert. *If nobody acts:* the escalation has its own ageing
clock and returns to the L1 owner's worklist at its breach. *Closes:* the specialist replies or returns it; the L1 owner closes.

### UC-SUP-4: Answer and close with a macro, and learn from it
**Actor:** Operator. **Trigger:** a routine question.
1. The operator inserts a **macro** for the family and the tenant's language and jurisdiction, edits placeholders, sends.
2. When the tenant confirms or after the agreed idle time the operator closes the ticket.
3. If the reply was new, the operator **promotes** it to a macro or a knowledge article (FR-SUP-C5), pending review by the article's owner.

**Alternates.** 2a. The tenant replies after closure: it arrives as a **new** ticket carrying the typed text (DECIDED).
**Completeness.** *Told:* the Owner Admin by the unread marker; the article owner by a review task.
*If nobody acts:* an answered ticket stays visible as "answered, not closed"; auto-close follows in a later wave.
*Closes:* closure by the operator; the satisfaction rating is requested once (SD10).

## Context and self-serve

### UC-SUP-5: The Owner Admin resolves an access problem without a ticket
**Actor:** Owner Admin (or Staff asking their Owner Admin). **Trigger:** "I cannot see the Purchases tab for Company B."
1. In FiSH, "Why can't I see this?" asks the **access explainer** (EA) with the person and the Company.
2. It answers from the real grants: "Amara is an Accountant at Company A only; Purchases needs the POP module at Company B."
3. The Owner Admin changes the grant in Team management, or decides not to.
4. If they still need help, **Ask support** raises a ticket with the explainer's output attached.

**Alternates.** 2a. The grants look right and it still fails: the ticket carries the explainer's result, which is the L2 starting point.
**Completeness.** *Told:* the Owner Admin immediately. *If nobody acts:* no cost. *Closes:* the grant is fixed, or the ticket takes over.

### UC-SUP-6: A suggested answer deflects a how-to
**Actor:** Owner Admin. **Trigger:** typing a new ticket.
1. As they type, FiSH shows up to three **articles** matching the family, their country and their industry (pulled from Omniview's knowledge base through the relay).
2. They open one; if it answers, they stop. If not, they send the ticket as normal; the articles they viewed are attached so the operator does not repeat them.

**Completeness.** *Told:* the article's owner sees the article viewed-then-ticketed count. *If nobody acts:* a stale article is
flagged after N months. *Closes:* the question is answered or becomes a normal ticket.

## Onboarding and proactive

### UC-SUP-7: Help a tenant that is stuck in onboarding
**Actor:** Operator; Owner Admin. **Trigger:** a **health signal** (FR-SUP-E2): onboarding idle for N days, or a verification deadline within 14 days.
1. The worklist lists the tenant with the signal, how long, and what is missing (from the card).
2. Under SD9's narrow rule, the operator sends a **notice** or opens an **operator-initiated thread**: "Your business verification is due by 12 March; here is what is still needed."
3. The Owner Admin sees it on the next pull and replies in the thread, or ignores it.
4. The signal clears when the missing step completes.

**Alternates.** 2a. SD9 is not approved: the operator uses a notice only, with no thread. 3a. No answer after the second prompt: the
operator notes it and stops; there is no third automatic contact. **Completeness.** *Told:* the Owner Admin, in app; the operator, on the
worklist. *If nobody acts:* the signal stays on the worklist and escalates to Femi at the deadline. *Closes:* the step completes, or the deadline passes and the tenant's status takes its normal course.

### UC-SUP-8: Support a migration to FiSH (opening figures)
**Actor:** Owner Admin; Operator; Specialist (accountant). **Trigger:** a migration ticket (family 3).
1. The operator opens the migration **case template**: anchor date, which modules, what each ledger needs, the rule that AR and AP are
   itemised (never a lump control-account import) and that unclassified balances go to the Suspense account for later itemisation.
2. They agree a plan with the Owner Admin in the thread; the accountant joins for the chart of accounts and the opening trial balance.
3. The tenant loads the figures (one by one today; bulk upload when built); the operator watches the onboarding progress on the card.
4. The accountant confirms the opening trial balance reconciles; the operator closes the case.

**Completeness.** *Told:* the specialist, by alert, at case start. *If nobody acts:* the case ages as P2 and shows on the month-end load forecast.
*Closes:* the opening trial balance reconciles and the Owner Admin confirms.

## Incidents, notices, problems

### UC-SUP-9: Handle an incident
**Actor:** Operator; Engineer; Femi. **Trigger:** several P1 tickets, a health strip showing a service down, or an engineer's report.
1. An operator **declares** an incident: title, severity, affected services, start time. The on-call is alerted.
2. Omniview lists **affected tenants** from the tickets and, by service and module, from the card data; a **notice** is published, targeted by module and jurisdiction.
3. Updates are posted on a cadence (P1: every 2 hours); linked tickets receive a one-line reply from a macro.
4. On resolution a **closing notice** goes out; a short post-incident note is written and linked.

**Alternates.** 2a. Omniview itself is down: the on-call tells tenants through whatever channel is left; the runbook names it. **Completeness.**
*Told:* on-call by alert; tenants by notice. *If nobody acts:* the incident record shows "no update for N hours" and alerts Femi. *Closes:* a closing notice and a post-incident note exist.

### UC-SUP-10: Turn many tickets into one problem, and close the loop
**Actor:** Operator; Engineer. **Trigger:** three or more tickets with the same cause.
1. The operator creates a **problem record**, links the tickets, and names the owning service and its backlog item.
2. The engineer fixes and marks the problem **fixed in release X**.
3. Every linked ticket's owner is prompted to tell the tenant (macro: "This is fixed in today's release").

**Completeness.** *Told:* the engineer (alert) and each ticket owner (task). *If nobody acts:* a problem with no owner or no update
for 14 days shows in the weekly review. *Closes:* every linked ticket has the "fixed" reply and is closed.

### UC-SUP-11: Publish a statutory change notice
**Actor:** Specialist (tax). **Trigger:** a rate or threshold changes in a country (for example Ireland's 9 percent VAT rate from 1 July 2026, Liberia's GST move).
1. The specialist writes the **change notice**: what changed, effective date, what the tenant must check or change, a link to the article.
2. It is targeted by jurisdiction (and by module TAX); FiSH pulls it into every affected Owner Admin's feed.
3. The specialist updates the knowledge article and the macros for that country.

**Completeness.** *Told:* the affected Owner Admins, in app. *If nobody acts:* the notice stays pinned until its effective date passes.
*Closes:* the effective date passes; the notice moves to history.

## Access, privacy, accounts

### UC-SUP-12: Diagnose a fault with the Owner Admin's permission
**Actor:** Operator or Engineer; Owner Admin. **Trigger:** a fault that cannot be understood from the ticket and the card.
1. The operator asks the Owner Admin, in the thread, for a **diagnostic grant**: "May I see the last failed postings for Company A for the next 60 minutes?"
2. The Owner Admin accepts in FiSH: scope (one Company, read-only, the named operator), duration, and a plain statement of what the operator will see.
3. During the window the operator uses the **diagnostic view**: statuses and reasons, not balances (FR-SUP-F5). Every read is logged.
4. The grant **expires on its own** or the Owner Admin revokes it. The operator records findings in an internal note and replies.

**Alternates.** 2a. Declined: support continues from the ticket alone. 3a. The grant expires mid-work: the operator asks again; nothing persists.
**Completeness.** *Told:* the Owner Admin sees the grant as active and when it ends; Femi can review the log. *If nobody acts:* it expires.
*Closes:* expiry or revocation; the log is retained.

### UC-SUP-13: The Owner Admin is locked out, has left, or may be compromised
**Actor:** Operator; Specialist (security); Femi. **Trigger:** a request that arrives outside the app (the ticket path needs a signed-in Owner Admin).
1. The operator does **not** act on the request; they start the **identity verification procedure** (out of band, against KYB and KYC records).
2. On a suspected compromise: P1, the security specialist is alerted, the account is secured through the tenancy's own recovery path (EA), and every action is logged.
3. For a departed owner: transfer of ownership is a **product gap** (single Owner Admin, no transfer built); Femi decides the manual route and it is recorded.

**Completeness.** *Told:* the security specialist and Femi, by alert. *If nobody acts:* the case is P1 and re-alerts hourly. *Closes:* the verified person regains access and the access is reviewed.

### UC-SUP-14: A verified data request (export, correction, erasure)
**Actor:** Owner Admin; Operator; Femi. **Trigger:** a ticket in family 11.
1. The operator confirms the requester is the Owner Admin of that tenant, **out of band**, and records how.
2. Femi approves. The export and any erasure follow the runbook (`docs/Omniview_Support_Operations_Runbook.md`), run through CM's credential-split path.
3. The operator tells the requester what was done and what remains (backups age out on schedule), and records counts, never content.

**Completeness.** *Told:* Femi (approval task) and CM (execution). *If nobody acts:* the ticket ages as P3 and shows in the weekly review; a statutory deadline flag is set on creation. *Closes:* the requester has the export or confirmation; the record is complete.

## Account and group

### UC-SUP-15: A group tenant asks about a second or third organisation
**Actor:** Owner Admin; Operator. **Trigger:** "We are adding a branch in Sierra Leone and a school arm."
1. The card shows the existing Companies. The operator explains the model: one tenant, a Company per legal entity, each with its own jurisdiction, currency, industry (fixed once chosen), modules, and staff roles per Company.
2. Industry cannot change later (a school cannot become a cement factory; a different industry is a different Company). Currency follows the Company; Mano River tenants use SLE.
3. The operator points to the self-serve route for adding a Company if one exists, or opens the onboarding checklist for the new Company.

**Completeness.** *Told:* the Owner Admin by reply; the specialist if tax or intercompany is involved. *If nobody acts:* the ticket ages normally. *Closes:* the Company exists and shows on the card.

### UC-SUP-16: A subscription or billing question (BLOCKED on a subscription system)
**Actor:** Owner Admin; Operator. **Trigger:** a family 9 ticket.
1. The card would show plan and subscription state; today it shows "no subscription system".
2. The operator answers from the default entitlement and records the question as a **requirement** for the subscription scoping.
3. A suspended or past-due tenant can still raise a ticket about the suspension and about exporting its own data (FR-SUP-H3).

**Completeness.** *Told:* Femi, a weekly digest of billing questions. *If nobody acts:* the digest repeats. *Closes:* when the subscription system exists, this use case is rewritten; until then the operator closes with a clear answer.

### UC-SUP-17: A tenant leaves
**Actor:** Owner Admin; Operator; Femi; CM. **Trigger:** a cancellation request.
1. The operator confirms identity (UC-SUP-13 step 1) and explains what happens: final export, retention period, deletion date.
2. A final export is produced (UC-SUP-14); services are told through their own channels (never by Omniview writing into them).
3. After the retention period the data is deleted and the Owner Admin is told once; the support record is retained or erased per SD13.

**Completeness.** *Told:* the Owner Admin at each stage; Femi and CM for the deletion. *If nobody acts:* the exit shows on a date-driven list. *Closes:* the deletion is confirmed and recorded. (Dependent on a subscription lifecycle.)

## Quality and learning

### UC-SUP-18: Capture feedback and measure satisfaction
**Actor:** Owner Admin; Operator. **Trigger:** closure, or a feature request inside a ticket.
1. On closure FiSH offers a one-tap rating and an optional comment (SD10).
2. The operator tags a feature request or complaint; it becomes a counted **feedback item** linked to the tenant.
3. The weekly review lists the top feedback items and low ratings.

**Completeness.** *Told:* Femi's weekly review. *If nobody acts:* the counts keep growing in view. *Closes:* an item is linked to a backlog entry, or declined with a reason that is sent back.

### UC-SUP-19: Manage the team's service levels
**Actor:** Femi (and a support lead later). **Trigger:** weekly, and on any SLA-breach alert.
1. The dashboard shows volume by family, severity, jurisdiction and industry; first-response and resolution against targets; backlog age; reopen rate; deflection; ratings; workload per operator.
2. A breach alert opens the ticket; the lead reassigns or helps.
3. Decisions (hours, staffing, new macros, new articles, routing changes) are recorded.

**Completeness.** *Told:* the lead, by alert and the weekly view. *If nobody acts:* repeated breaches raise a standing alert to Femi. *Closes:* the breach is resolved and the cause noted.

### UC-SUP-20: A school tenant needs help in its own language of work
**Actor:** Owner Admin of a School Company; Operator; Education owner (L2). **Trigger:** a ticket about admissions, guardian fee invoices or timetabling.
1. The industry on the card is SCHOOL and the Education Runtime module is on; routing sends the ticket to the **Education lane**.
2. The operator uses the **School playbook** (common questions, the owning service, the articles) and answers or escalates to the Education owner.
3. A defect is linked to a problem (UC-SUP-10); a "how do I" becomes an article tagged SCHOOL.

**Completeness.** *Told:* the Education owner, by alert, on escalation. *If nobody acts:* ageing as UC-SUP-3. *Closes:* as for any ticket. Each new industry repeats this case with its own lane and playbook.
