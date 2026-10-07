OMNIVIEW (PRODUCT SUPPORT CONSOLE) PLAYBOOK (operator sheet, service OMNIVIEW)

Written by the Omniview session, 2026-10-07, from the code in fish-er-omniview (branch feat/omniview-support-s5, commit 40a04e7). Deployed to production on master up to 99c0f49 (task definition fish-er-omniview:6, Flyway v15, which includes Waves S1 to S6 and S8.1). NOT yet deployed: the playbook-by-subject change in 40a04e7 (migration V16). Everything below is what the code does TODAY. The last section lists what is NOT built, not deployed, or not yet exercised, so nobody promises it to a customer. Update this in the same change as the code it describes. Where this says "not exercised live", the code and its tests do it but nobody has watched it happen in production, because the console is private.

PLAYBOOK CONTENTS (see docs/Playbook_Definition.md; a playbook is this sheet PLUS the SPUTO set)
1. Operator sheet: this document.
2. Scope: docs/Omniview_Extraction_DDD_Design.md (why Omniview is its own service), docs/Omniview_Support_Model_SRS.md sections 1 and 2 (the problem support must solve and the twelve families of need), docs/Omniview_SPUTO_v2_Seed.md.
3. Plan / SRS: docs/Omniview_Support_Model_SRS.md (the support model, FR-SUP and NFR-SUP), docs/Omniview_Software_Requirements_Specification.md (the platform operator console), docs/Omniview_v2_Software_Requirements_Specification.md (v2).
4. Use cases: docs/Omniview_Support_Model_Use_Cases.md (UC-SUP-1 onwards), docs/Omniview_Use_Cases.md, docs/Omniview_v2_Use_Cases.md.
5. Tasks: docs/Omniview_Support_Model_Backlog.md (Waves S0 to S10, with status per row), docs/Omniview_Backlog.md, docs/Omniview_v2_Backlog.md.
6. Order: docs/Omniview_Support_Model_Backlog.md is dependency-ordered by wave (its "Risks to the order" section says what must come before what), and the per-wave contracts record each decision: docs/Omniview_Support_S2_Tenant_Context_Contract.md, S3_Self_Serve, S4_Notices_Incidents_Problems, S5_Onboarding_Health, S6_Lanes_Routing_Escalation, S8_Data_Requests, docs/Omniview_Support_Published_Content_Contract.md, docs/Omniview_Support_S7_Diagnostic_Access_Threat_Model_And_Design.md (design only; on a branch, not merged yet), docs/Omniview_Support_Operations_Runbook.md (how to run it), docs/Omniview_Support_E2E_Verification.md.
Not written yet: a single merged SRS. Omniview has three requirements sets (the first operator console, v2, and the support model) that were written in turn and overlap; the support model is the current one. The foundations (strict decoding of what other services send, fail-closed configuration, idempotent submits, read-only toward every other service, a tenant sees only its own data) are stated in the support model's non-functional requirements, not as a separate ordered list.

OWNING SERVICE
Omniview, the support console for Prodeo's own team (repo fish-er-omniview). It is private: it is reached only over the SSM bastion on port 8090, never from the internet, and a tenant never sees it. The Omniview session is the L2 for anything about the console itself. Deploys, task definitions, environment variables and secrets belong to Configuration Management (CM), never to the Omniview session.

ESCALATE TO
The console misbehaves, a screen is wrong, or an alert did not arrive: the Omniview session. Deploy, environment variable, secret, alert-delivery or database problems: CM. A tenant's membership, verification, the tenants list or the support card: EA. Approving a data request, naming a lane's owner, a policy question: Femi. A question about law, privacy, or what a business is owed: the solicitor, through Femi, never an answer from support.

HELP ARTICLES
None are written yet. The knowledge base and the published help files work, but nobody has written the first articles. Do not invent links, and say so if asked.

HOW ACCESS WORKS (needed for most "I cannot ..." questions about the console)
Operators sign in with a named token (the X-Operator-Token header, set up by CM in OMNIVIEW_OPERATOR_TOKENS). The console asks for it once per browser session.
- 401: a wrong or missing token. 429: too many wrong tries from one place (ages out after five minutes). 503 "not_configured": no operator token is configured at all, which is a CM problem.
- Some steps are administrators only, decided by OMNIVIEW_ADMIN_OPERATORS: the access log, and approving, exporting and erasing in a data request. A non-administrator gets 403 "forbidden". In production at 2026-10-06 there is ONE operator and ONE administrator (operator-1), so the two-person rule on data requests is off and the same person can do every step. That is acceptable only while all data is legacy test data; the live switch needs at least two operators.
- Businesses reach Omniview only through EA's relay (service credential); an operator never sees a business's login. Omniview never writes into another service.

WHAT EACH TAB DOES, AND WHAT NOT TO PROMISE
Tickets: the queue and a ticket's thread, triage (family, severity, lane, country), ownership, tags, internal notes, history, a reply, close. The tenant clock runs only while a business is waiting and only in working hours (08:00 to 18:00 UK, Monday to Friday; bank holidays are not modelled). Targets: P1 one hour, P2 four hours, P3 one working day, P4 three. A staff alert goes to the one support mailbox, with no ticket text. Do not promise a reply time outside those hours. Do not promise an email or a push to the business: a reply is shown in the app the next time it opens.
Case tab: a fixed checklist for a long job (today only the migration to FiSH: anchor date, modules, chart of accounts, receivables and payables itemised and never one control total, unclassified balances to Suspense, figures loaded, accountant confirms the trial balance, owner confirms). Ticking records who and when. It does not load any figures.
Escalation tab: hands the ticket to an L2 or L3 lane with a required handoff note; the business still sees one thread. "Also tell the business" posts a plain reply and COUNTS AS OUR ANSWER for the response clock, so it is your choice. The escalation has its own clock (provisional: an L2 lane eight working hours, an L3 lane twenty). Past it the ticket is flagged once and shows in the attention view; it is not moved.
Tenant tab: what Omniview holds about the business (its tickets) and, when EA's support card route exists and the Owner Admin has allowed it, EA's view of its set-up. Until then it says "unavailable". Never say a business "has not allowed it" unless the card says exactly that.
Playbook tab: the operator sheet for the ticket's industry and for the service it was raised from, if one has been written.
Canned replies: versioned replies by family and language with a fixed set of placeholders. They fill only the business name, your name and the ticket id.
Articles: plain-text help articles, versioned, published or withdrawn. A published article reaches the business as a static file in a few minutes; withdrawing stops it showing within about a minute for new page loads, but cannot recall what was already read. Never put a name or a personal detail in an article.
Notices: messages Prodeo tells businesses, targeted by service, industry, country or named businesses. A notice with NO businesses listed is published openly: anyone with the link can read it, so never put a business name or personal detail in one. A notice for named businesses is delivered only to them. A published notice is never edited: withdraw it and publish another.
Incidents: declare with a severity and the services affected; the state only moves forward; resolving withdraws the incident's notices and can publish a one-day "resolved" notice. The post-incident note is internal only.
Problems: one cause behind several tickets. Marking one fixed in a release replies on every still-open linked ticket and sends those businesses one notice, once, and cannot be undone.
Worklist: businesses that need a nudge (verification flagged, overdue or due within 14 days, no company on a draft, phone not verified), worked out when you open it from EA's tenants list. "Seen for N days" counts from when Omniview first saw the signal. A reminder is a notice to that one business: at most two per signal, three days apart, plain text with no name or figures, withdrawn when the signal clears. It does not email and does not open a thread.
Lanes: who answers what, and the rules that route a ticket (first match wins; a lane a person chose is never changed by routing; there is a dry run). Owners and backups are not named yet: it will say "not named yet".
Playbooks: the operator sheets (this kind of document), one per industry or service.
Data requests: export and erasure on a verified request. Opened on a real ticket, identity confirmed outside the ticket, approved by an administrator, then done. Export is built when you press the button and stored nowhere. Erasure shows a preview and needs the typed phrase (ERASE and the first eight characters of the business's id). DO NOT RUN A REAL ERASURE IN PRODUCTION until Femi has agreed what it may erase (see the NOT BUILT list).
Metrics: counts and response times about tickets only, never a business's books.
Access log: every card opened, ticket read and change, by named operator, append-only. Administrators only.
Tenants and Legacy threads: EA's platform tenants view and the older read-only message threads. They are EA's data, shown here.

COMMON QUESTIONS
Q: A business says it never saw our reply. A: Replies are pulled, not pushed: the app shows an unread marker the next time the business opens it. Nothing is emailed to them. Check the thread to confirm the reply exists.
Q: The tenant card says "unavailable". A: EA's support card route is not built yet (checked 2026-10-06), or EA could not be reached. Say nothing about the business's set-up from it. Tickets are unaffected.
Q: A business wants to see what we hold about them. A: Open a data request (export). Do not paste anything out of a ticket into a chat. Identity must be confirmed outside the ticket first.
Q: A business wants everything deleted. A: Open a data request (erasure) and stop there until Femi approves. Tell them honestly that erasure covers what Omniview holds, not EA's own records, logs or backups (the solicitor's wording is pending).
Q: A business asks whether it should register for VAT, or what to do about its tax. A: That is a professional judgement. Mark the ticket as needing one (the console then shows a banner), explain only how the product works, and say a separate engagement by Prodeo Capital's accountants is how that help is given. The wording for the business is not written yet (legal advice pending): do not improvise it.
Q: Why did a ticket land in lane X? A: Routing rules chose it at creation or when triage changed the family or country; the ticket's history shows "routing rule N" as the actor "routing". A person's choice of lane is never overridden.
Q: Can support look at a business's ledger to find the fault? A: No. There is no diagnostic access today. Ask the Owner Admin what they see, and escalate with request ids. A consent-gated view is designed, not built.
Q: A notice or article still shows after I withdrew it. A: For new page loads it stops within about a minute; a page already open may keep showing it until refreshed.

WHAT THE ERRORS MEAN
401 unauthorized: wrong or missing operator token. 429 rate_limited: too many wrong tries. 403 forbidden: that step is for administrators. 404 not_found variants (ticket, lane, rule, playbook, request): it does not exist for that business. 413 payload_too_large: the text is over the route's size limit (an ordinary request 16 KiB, an article 96 KiB, a playbook sheet 256 KiB). 503 ea_unavailable (with a code): EA could not be read; nothing was changed; try again. 503 not_configured: a setting is missing (CM).
validation_failed details you will see: state_not_allowed or use_resolve (an incident only moves forward and ends through Resolve); already_escalated, lane_not_a_specialist_lane, handoff_note_required (escalation); signal_not_present, not_stuck_yet, outreach_too_soon, outreach_limit_reached (reminders); lane_in_use (a rule still routes to that lane); playbook_exists (one live sheet per subject); not_awaiting_verification, not_awaiting_approval, approver_must_differ_from_verifier, approval_expired (seven days), confirmation_mismatch, not_approved (data requests); case_already_applied (a ticket's checklist is attached once).

NOT BUILT, NOT DEPLOYED, OR NOT YET EXERCISED (do not promise these)
- Diagnostic access to a business's data (Wave S7): designed only. No operator can see a business's books, and none should ask for a password or a screenshot of one.
- Operator-initiated threads: support cannot open a ticket to a business. Reminders go as notices.
- A scheduled refresh and automatic escalation at a verification deadline: the worklist is worked out when someone opens it, because Omniview has no service credential for EA.
- Ledger-based onboarding steps (chart of accounts, first posting, period opened) and the month-end load forecast: they need a read route in the ledger that does not exist.
- Retention, exit across services and a residency statement (S8.2 to S8.4): waiting on the solicitor, a subscription system and CM. Today tickets are kept until erased on a verified request.
- Correction of ticket text: handled by hand and noted on the request.
- Erasure does NOT reach EA's own legacy support-thread messages, CloudWatch logs (ticket ids), the alert emails to the support mailbox, or database snapshots and backups. The processing terms must say so; the solicitor has not yet.
- The export includes internal notes about the business; whether it should is a solicitor question.
- Lane owners and backups are not named; the escalation clocks are provisional; the support mailbox is the only alert channel and there is no on-call roster.
- Not exercised live: the Worklist, Lanes, Playbooks and Data requests tabs. CM cannot reach the private console and nobody has yet looked at them in production. Tickets, the queue, replies and alerts were exercised in the first end-to-end test; see docs/Omniview_Support_E2E_Verification.md.
- Business-facing parts that belong to other services and are not confirmed built: the help screen and the notice banner in the app (WEB), country for notice targeting (unknown today, so country-targeted notices fail open and everyone sees them), and the public status page (CM).
- No push or email to a business for a reply, no French, no second channel (Wave S10), no subscription or billing support (Wave S9, which needs a subscription system that does not exist).
- One operator and one administrator in production; the live switch needs at least two.
