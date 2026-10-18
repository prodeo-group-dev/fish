ENTERPRISE ADMINISTRATION (EA) PLAYBOOK (draft for Omniview's Playbooks tab, service EA)

Written by the EA session, 2026-10-07; refreshed 2026-10-18 from the code on fish-enterprise-administration master (e21b825, PR 61). I have not checked which task definition is running now: CM reported EA :103 live on 2026-10-15; the later releases (PAYROLL enable prepared inert, Accountant IM default) are on master and I have not confirmed they are deployed, so verify before telling anyone they are live. EA is the Owner Admin's toolkit; the Owner Admin is the business owner, a person. Where this sheet says what is NOT built or not yet exercised, believe that over any older document.

PLAYBOOK CONTENTS (see docs/Playbook_Definition.md; a playbook is this sheet PLUS the SPUTO set)
1. Operator sheet: this document.
2. Scope: the EA SCOPE section at the end of this sheet (written 2026-10-18). Longer material: EA/docs/EA_MVP_Definition.md, EA/docs/Business_Owner_ERP_Model_DDD_Design.md (in the EA repo) and the broader charter in EA/docs/Business_Owner_Mobile_ERP_Requirements_Use_Cases.md.
3. Plan / SRS: docs/Staff_Onboarding_Offboarding_SRS.md (staff onboarding and offboarding), docs/Omniview_v2_EA_Route_Contracts.md (the support relay's routes), docs/EA_Communication_Centre_Contract.md and docs/Unified_Communication_SRS.md (messaging), docs/Tenancy_Administration_Extraction_DDD_Design.md (tenants, users, memberships, roles), docs/Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md (the cross-service contract), docs/Cross_Service_Contract_Fixtures_SPUTO.md (the golden contract files EA decodes and provides), docs/EA_Payroll_Module_Design.md (EA's part of the payroll split), docs/EA_Company_Tenant_Lookup_Design.md, docs/EA_Concurrent_Writes_Playbook.md and docs/EA_Dashboard_At_A_Glance_Playbook.md. The audit record shape (T17) is in docs/reports/Playbooks/EA/EA_Audit_Record_Shape_T17.md. Not written: an SRS for the dashboard ratios, the approvals queue, and verification/KYC reminders (each has only its code and its tests).
4. Use cases: docs/Staff_Onboarding_Offboarding_Use_Cases.md, docs/Unified_Communication_Use_Cases.md, EA/docs/Business_Owner_Mobile_ERP_Requirements_Use_Cases.md.
5. Tasks: docs/Staff_Onboarding_Offboarding_Backlog.md (with its coordination register), plus rows in docs/GL_POP_IM_SOP_Backlog.md where EA is named; the contract-fixture tasks (T8, T9) in docs/Cross_Service_Contract_Fixtures_SPUTO.md.
6. Order: the EA ORDER section at the end of this sheet (written 2026-10-18); the staff onboarding order inside docs/Staff_Onboarding_Offboarding_Backlog.md (Waves 0 to 6) is one input to it.

OWNING SERVICE
Enterprise Administration (repo fish-enterprise-administration, live at ea-api.theprodeogroup.com). EA owns tenants, users, memberships, roles and per-Company access, the Owner Admin's dashboard and approvals queue, the staff communication centre, and the relay between a tenant's Owner Admin and Omniview's support tickets. Every other FiSH service asks EA "who is this person and what may they do at this Company" through GET /me.

ESCALATE TO
Owner: the EA session. Deploys, environment variables and secrets: CM. Ledger or VAT questions: GL. Employment records (Personnel) and payroll: the HR and Payroll sessions, who write their own playbooks and report to EA when they are running in the organisation (Femi, 2026-10-18). Support ticket content: Omniview.

HELP ARTICLES
None written. Do not invent links; say so if asked.

HOW ACCESS WORKS (needed for most "I can't do X" tickets)
- A person signs in with Cognito; EA reads the verified email from the token and finds their User. If they have no ACTIVE membership anywhere the answer is 401 unauthorized (not 403). A pending invite, a revoked membership or an expired employment window does not count as active.
- A membership is per Tenant, and inside it per Company: a role, an access level (NONE, READ, WRITE, APPROVE, ADMIN) and the modules granted (GL, HR, SOP, POP, IM, TAX, EDUCATION_RUNTIME). The Owner Admin has READ at every Company of his own Tenant automatically, but NO module grants; each service decides what that means (SOP, since 2026-10-07, treats him as WRITE on Sales).
- 403 forbidden means signed in but not allowed. 404 company_not_found can also mean "not your Tenant's Company"; EA hides that difference on purpose.
- Only the Owner Admin can: read the dashboard, read the approvals queue, read his verification status, raise or manage support tickets, approve company links, send to the whole business or to a role. Service accounts (the other FiSH services) skip the person check; they cannot call the human routes.

COMMON QUESTIONS AND HOW TO ANSWER

SIGNING UP AND VERIFICATION
Q: "What does a new business have to do before it can work?"
A: A business starts working immediately; only a FLAGGED check blocks it. The minimum is the Owner Admin's verified email and, by the 14th day, his verified phone. The phone is a REMINDER only: nothing suspends a business for an unverified phone (changed 2026-10-07). The business check (KYB) and the Owner Admin's own KYC have one shared 180-day deadline; after it a scheduled sweep suspends the business.
Q: "Where does the Owner Admin see what is due and by when?"
A: GET /api/tenants/{id}/verification (Owner Admin only) returns his KYB and KYC status, the 180-day deadline, his phone status and the 14-day phone deadline. The reminder days (90, 150, 166, 173, 179) are NOT sent by EA; WEB computes them for an in-app banner from that deadline.
Q: "My business was suspended." 
A: Either the 180-day verification deadline passed with the business check or the Owner Admin's KYC not yet VERIFIED, or an operator suspended it. Escalate to the EA session with the tenant id; do not promise reinstatement.

COMPANIES
Q: "industry_type_immutable" or "company_registration_rejected".
A: A Company's industry type cannot change after registration, and a Company already belonging to another business cannot be registered again. A school ("SCHOOL") Company is only registered if the Education Runtime creates its school first; "school_provisioning_failed" means that call failed, nothing was registered, try again later or escalate with the tenant id.

TEAM AND ROLES
Q: "How does the Owner Admin add or remove staff?"
A: In Personnel (under Administration), each employee row has "Give access" or "Remove access" and there is one button, "Invite someone who isn't an employee" (WEB shows this as the Team section until its rename to Personnel lands). The Business Owner has the final authority over hiring and firing: the Owner Admin can do each directly, and the intended end state (not built) is that anyone else raises the change and only the Owner Admin approves it. Until that request flow exists, the EA route still lets an HR Officer with ADMIN access invite, change modules and remove staff directly (Femi, 2026-10-15: delegates keep acting directly until the flow exists). An invite is a pending membership until the person accepts with their own sign-in; it can expire ("expired") or be answered already ("already_responded"). A removed member gets 409 already_revoked if removed twice. The Owner Admin can never be removed or created by an invite.
Q: "Why can't a teacher see Finance?"
A: Access follows the module grants at the Company. A teacher has none unless the Owner Admin grants them. The staff onboarding design (HR -> EA -> Education Runtime) is NOT built.

DASHBOARD AND RATIOS
Q: "Why is a ratio blank, with a reason?"
A: Each ratio says why: no_sales, no_equity, no_assets, no_current_liabilities mean the figure on the bottom is zero or negative; needs_cost_of_sales, needs_operating_profit, needs_interest_expense, needs_share_count, needs_dividends, needs_market_price, needs_inventory_data, needs_ledger_data mean the platform does not hold that figure yet. Profit figures are for the current OPEN period and are not annualised, so a part-period figure looks small.
Q: "The dashboard says 403."
A: The dashboard is the Owner Admin's alone (since 2026-10-07). A staff member, even with access to the Company, is refused by design.
Q: "A dashboard section is missing."
A: Each section (sales today, inventory, cash flow, profit, ratios) is left out when its source service did not answer; the page still loads. Escalate only if it persists.
Q: "Why do gross margin, operating margin, return on capital employed and interest cover say 'not available yet'?"
A: They come from the ledger's trading profit-and-loss report (since 2026-10-07) and need the Company's accounts to be TAGGED in GL: gross margin needs a cost-of-sales account tagged (needs_cost_of_sales); operating margin, return on capital employed and interest cover need the INTEREST account tagged (needs_interest_expense), because untagged interest hides inside operating expenses and would understate operating profit. Companies created before GL release :98 have no tags yet; only newer Companies get cost of sales (5010), interest (5600) and income tax (5700) from the chart template. Existing Companies need GL's re-tag route or new accounts: escalate to the GL session. needs_operating_profit means the report did not answer at all. no_interest_expense means the interest account is tagged but nothing was paid. no_capital_employed means total assets minus current liabilities is zero or negative.
KNOWN LIMIT: an untagged income-tax account can still understate operating profit (GL's report has no flag for it yet). Do not promise these four ratios are exact for a Company whose tax is untagged.

APPROVALS QUEUE
Q: "What is in it?"
A: Pending customer returns (Sales), stock adjustments (Inventory), supplier returns (Purchases) and payroll runs (HR). It is read-only here; approving happens in each service. A source that did not answer is listed under sourcesUnavailable.

COMMUNICATION CENTRE
Q: "Who can message whom?"
A: The owner reaches anyone and anyone reaches the owner; members of one Company reach each other; members of different Companies only if the Owner Admin has linked those two Companies (403 cross_company_not_approved). Module channels belong to one Company and need that module there (403 forbidden). Lists return the newest 50 (limit 1 to 200, before=<message id>); a message body is at most 4000 characters (400 message_too_long). invalid_limit and invalid_cursor name a bad parameter.

SUPPORT (the Owner Admin's tickets to Omniview)
Q: "Support says unavailable."
A: 503 support_unavailable means EA has no connection to Omniview configured. At the last check (2026-10-06) the support relay was built and deployed but its switch-on (six EA_OMNIVIEW_* settings and a Terraform apply) was pending Femi and CM; verify before telling anyone it works. Only the Owner Admin can raise or read tickets. 429-style limits apply (20 writes and 120 reads a minute); a message over 4000 characters is refused.

INVOICE REPLY-TO (for Sales)
Q: "Where does the invoice's Reply-To come from?"
A: Sales Order Processing asks EA for the Owner Admin's verified email and name through a service-only route (since 2026-10-07). If EA cannot answer, SOP sends nothing (its 503 email_not_configured). EA logs the Company id of each call, never the email.

PAYROLL MODULE, ACCOUNTANT DEFAULTS AND THE SWITCH (EA's part of the payroll split)
Q: "Why can't I give someone the Payroll module?"
A: PAYROLL exists as a module value but is WITHHELD from every grant until Femi announces the switch. An invite or a modules change that asks for it is refused with 422 module_not_yet_available and nothing changes. At the switch only Owner Admins and Accountants get it (existing HR WRITE holders do not; Femi, 2026-10-15). HR's own checks (HR_ENFORCE_PAY_SPLIT) are HR's, default off, and do not exist yet as far as I last checked.
Q: "How will a business be warned about who loses Pay runs?"
A: GET /api/tenants/{tenantId}/payroll-switch-notice (Owner Admin only) lists who holds PAYROLL from the switch date and which people can prepare a pay run today but will not be able to unless the Owner Admin grants them PAYROLL. Until CM sets EA_PAYROLL_SWITCH_DATE it answers 404 not_scheduled, so it tells nobody anything. A read-only SQL file, EA/scripts/payroll_switch_day_report.sql (opaque ids and counts only, no names or emails), gives Femi the same counts across every business.
Q: "What modules does an Accountant get by default?"
A: GL, TAX and IM (Femi, 2026-10-18, so an accountant can set product VAT categories and record opening stock), plus PAYROLL once it is enabled. This applies to new Accountants (registration, or an invite that names no modules). Existing Accountants are changed only if CM starts EA with EA_ACCOUNTANT_IM_BACKFILL=dry-run or execute (unset = never; add-only, dry run first). The PAYROLL backfill works the same way with EA_PAYROLL_BACKFILL and refuses while PAYROLL is withheld.
Q: "Who can add or remove staff?"
A: The Owner Admin, and today also an HR Officer with ADMIN access at that Company, directly. The end state decided by Femi (2026-10-15) is that anyone but the Owner raises the change and only the Owner Admin approves it; that request flow is HR's to build and is not built. Do not promise an approval step exists.

SCHOOLS AND THE EDUCATION RUNTIME
Q: "Why can't I give a teacher the Education Runtime at my business?"
A: Only a school has an Education Runtime. EA refuses an invite or a modules change that grants EDUCATION_RUNTIME at a Company it does not record as a school, with 422 module_not_allowed_for_industry, and refuses to change a registered Company's industry afterwards (409 industry_type_immutable). SOP asks EA whether a Company is a school through a service-only route that answers only {"industryType":"SCHOOL"|"GENERIC"}.

WHEN SOMETHING IS BUSY OR CACHED
Q: "I got 409 tenant_busy."
A: Another change to the same business's staff is still running; nothing of this one ran. Wait a moment and retry. EA takes a short per-business lock on every staff write.
Q: "Does the app or the browser keep a copy of EA's answers?"
A: No. Every EA answer carries Cache-Control: no-store, private, success or error (pinned by a test since 2026-10-15). Femi's mobile decision (2026-10-15) is that nothing of a business's data persists on the phone.

THE DASHBOARD "SALES TODAY"
Q: "Why is Sales today lower than my invoices total?"
A: It is NET, labelled (excluding VAT) (Femi, 2026-10-15). A figure with VAT included is not shown unless Femi asks for it, and then it needs a gross amount declared by Sales.

ERROR GLOSSARY (EA's fixed tokens)
unauthorized (401), forbidden (403), not_found, company_not_found, tenant_not_found, user_not_found, bad_request, validation_failed, expired, already_responded, already_revoked, payload_too_large, message_too_long, message_not_found, invalid_limit, invalid_cursor, role_access_denied, channel_access_denied, company_access_denied, cross_company_not_approved, invalid_company_link, company_not_in_tenant, company_registration_rejected, industry_type_immutable, school_provisioning_failed, support_unavailable, ticket_not_found, ticket_closed, idempotency_key_reused, ambiguous_company_owner, not_owner_admin, not_configured, module_not_yet_available (422), module_not_allowed_for_industry (422), tenant_busy (409), not_scheduled (404).

WHAT TO COLLECT BEFORE ESCALATING
The person's email, the tenant id and company id, the exact route and the error token, and the time. Never ask for a password or a token.

NOT BUILT, NOT DEPLOYED OR NOT YET EXERCISED (as of 2026-10-18)
- Staff onboarding and offboarding as an approved REQUEST (HR raises, only the Owner Admin approves, then EA grants or removes access; the hire-to-access leg; the employment-window rule; the generic STAFF role; the Education Runtime hand-off): designed, nothing built. HR owns the request machinery. Until it exists a delegate with ADMIN can invite, change modules and remove staff directly.
- Enabling the PAYROLL module: prepared inert on master (backfill, Accountant default, switch-day warning route, report) but WITHHELD; enabling is a separate deliberate release after HR's checks are deployed off. None of the enable steps has run in production as far as I know.
- An audit log in EA (T17b): the shared record shape is designed, EA's own table and writers are not built. EA records no per-act audit rows today beyond what each aggregate stores.
- Sign-out of all devices, a list of signed-in devices, push notifications and the app's minimum-version file: planned only (see docs/reports/Playbooks/EA/EA_Mobile_App_Items_2026-10-15.md). The decided app settings are an access token of 15 minutes and a refresh token of 7 days (Decisions_Log, 2026-10-15); I have not checked that they are configured live, and a remote sign-out cannot cancel a token already issued.
- Email or in-app delivery of the verification reminders (90, 150, 166, 173, 179 days): not built in EA; WEB computes an in-app banner.
- The Owner Admin's diagnostic-access grant for Omniview (S7) and the support card: designed or planned; the support relay's switch-on status was pending Femi and CM at the last check (2026-10-06) and I have not re-verified it.
- Database-level isolation between businesses (row-level security): deliberately not built; the app layer enforces it (docs/Database_Tenant_Isolation_RLS_Scope.md).
- Real-login checks of some newer routes (the payroll switch notice, the internal industry route, the HR run mirror's selfApproved field): covered by tests; not exercised with a real sign-in or with HR sending the field yet.
- Multi-tenant callers: SOP and the ledger are bound to one Tenant per deployment; EA itself is multi-tenant.

EA SCOPE (written 2026-10-18)
EA is the Business Owner's information and access toolkit. It answers "who is this person and what may they do at this Company" for every FiSH service (GET /me, unchanged in shape), runs the Owner Admin's dashboard, approvals queue, verification status and communication centre, relays the Owner Admin's support tickets to Omniview, and holds the tenant, user, membership, role and module records. It is NOT the owner of any business data (ledger, sales, purchases, stock, people records, pay): those belong to GL, SOP, POP, IM, HR and Payroll, which EA reads only to inform the Owner. Prodeo is a landlord with no role in a business's data (Femi, 2026-10-15): nothing in EA lets an operator read or edit business data. EA does not build legal, consent or agreement features (Femi). The specialised services (HR, Payroll, the Education Runtime) write their own playbooks from their own SPUTOs and tell EA when they run in the organisation; EA adapts its access and dashboard sources then.

EA ORDER (written 2026-10-18; dependencies first, estimates are mine and unproven)
1. Foundations already in place: per-Tenant write lock (409 tenant_busy), strict decoding of every cross-service payload with golden contract files (consumers declare a new field first), no-store on every answer, fail-closed school check. Keep them first for anything below.
2. Consumer-first declarations: EA's mirrors declare a producer's new field before the producer ships it (done for HR's selfApproved on a payroll run).
3. PAYROLL enable (EA): after HR's enforcement is deployed off and Femi announces the switch: remove PAYROLL from the withheld set (about 0.75 day), run the backfill dry then execute (about 1 day with its migration test, only once the EA release is stable), set the switch date so the Owner Admin warning route lights (CM). The approvals queue showing pending runs to PAYROLL APPROVE holders follows HR's confirmed list contract (about 1 day).
4. Audit log (T17b, about 1.5 days) once Femi approves the audit record shape; then the document-download rows that the mobile app needs.
5. Access-change approval (hire, change, remove access by request): HR builds the machinery, EA executes the access leg; blocked on HR and on the generic STAFF role decision. Femi's open question whether it must exist before the Live switch (P8).
6. Mobile items in order: sign out of all devices first (about 1 day plus an IAM permission from CM), then the first push (a verification-days reminder from EA's own data), then a spike on a per-device list.
7. Dashboard and ratios SRS, approvals queue SRS and verification-reminder SRS: write when each is next changed; today each has only its code and tests.
