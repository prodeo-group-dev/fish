ENTERPRISE ADMINISTRATION (EA) PLAYBOOK (draft for Omniview's Playbooks tab, service EA)

Written by the EA session, 2026-10-07, from the code on fish-enterprise-administration master (commit 9b46901, running as task definition fish-enterprise-administration:76). EA is the Owner Admin's toolkit; the Owner Admin is the business owner, a person. Where this sheet says what is NOT built or not yet exercised, believe that over any older document.

PLAYBOOK CONTENTS (see docs/Playbook_Definition.md; a playbook is this sheet PLUS the SPUTO set)
1. Operator sheet: this document.
2. Scope: EA/docs/EA_MVP_Definition.md and EA/docs/Business_Owner_ERP_Model_DDD_Design.md (in the EA repo; the broader charter is EA/docs/Business_Owner_Mobile_ERP_Requirements_Use_Cases.md). Not written: a single short EA scope statement; the three documents above overlap.
3. Plan / SRS: docs/Staff_Onboarding_Offboarding_SRS.md (staff onboarding and offboarding), docs/Omniview_v2_EA_Route_Contracts.md (the support relay's routes), docs/EA_Communication_Centre_Contract.md and docs/Unified_Communication_SRS.md (messaging), docs/Tenancy_Administration_Extraction_DDD_Design.md (tenants, users, memberships, roles). Not written: an SRS for the dashboard and ratios, the approvals queue, and verification/KYC reminders (each has only its code and its tests).
4. Use cases: docs/Staff_Onboarding_Offboarding_Use_Cases.md, docs/Unified_Communication_Use_Cases.md, EA/docs/Business_Owner_Mobile_ERP_Requirements_Use_Cases.md.
5. Tasks: docs/Staff_Onboarding_Offboarding_Backlog.md (with its coordination register), plus rows in docs/GL_POP_IM_SOP_Backlog.md where EA is named.
6. Order: the dependency order is inside docs/Staff_Onboarding_Offboarding_Backlog.md (Waves 0 to 6). Not written: an order across EA's other work (verification reminders, support card, diagnostic grant).

OWNING SERVICE
Enterprise Administration (repo fish-enterprise-administration, live at ea-api.theprodeogroup.com). EA owns tenants, users, memberships, roles and per-Company access, the Owner Admin's dashboard and approvals queue, the staff communication centre, and the relay between a tenant's Owner Admin and Omniview's support tickets. Every other FiSH service asks EA "who is this person and what may they do at this Company" through GET /me.

ESCALATE TO
Owner: the EA session. Deploys, environment variables and secrets: CM. Ledger or VAT questions: GL. Payroll and employment records: HR. Support ticket content: Omniview.

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
A: Invite from the Team tab (Owner Admin only in the screen; the EA route also lets an HR Officer with ADMIN access do it, pending Femi's decision). An invite is a pending membership until the person accepts with their own sign-in; it can expire ("expired") or be answered already ("already_responded"). A removed member gets 409 already_revoked if removed twice. The Owner Admin can never be removed or created by an invite.
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

ERROR GLOSSARY (EA's fixed tokens)
unauthorized (401), forbidden (403), not_found, company_not_found, tenant_not_found, user_not_found, bad_request, validation_failed, expired, already_responded, already_revoked, payload_too_large, message_too_long, message_not_found, invalid_limit, invalid_cursor, role_access_denied, channel_access_denied, company_access_denied, cross_company_not_approved, invalid_company_link, company_not_in_tenant, company_registration_rejected, industry_type_immutable, school_provisioning_failed, support_unavailable, ticket_not_found, ticket_closed, idempotency_key_reused, ambiguous_company_owner, not_owner_admin, not_configured.

WHAT TO COLLECT BEFORE ESCALATING
The person's email, the tenant id and company id, the exact route and the error token, and the time. Never ask for a password or a token.

NOT BUILT, NOT DEPLOYED OR NOT YET EXERCISED (as of 2026-10-07)
- Staff onboarding and offboarding through HR with the Owner Admin's approval, the employment-window rule, the generic STAFF role, the HR-only internal route and the Education Runtime hand-off: designed (docs listed above), nothing built.
- Email or in-app delivery of the verification reminders (90, 150, 166, 173, 179 days): not built in EA.
- The Owner Admin's diagnostic-access grant for Omniview (S7) and the support card: designed or planned only.
- Real-login checks of the Owner Admin verification route and of SOP's owner-contact call: verified by tests and unauthenticated 401s only until their first real use.
- The Owner Admin does not yet get module access beyond Sales automatically; other modules still need an explicit grant.
- Multi-tenant callers: SOP and the ledger are bound to one Tenant per deployment; EA itself is multi-tenant.
